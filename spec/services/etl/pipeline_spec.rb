require "rails_helper"
require "roo"

RSpec.describe Etl::Pipeline do
  let(:run) do
    ProcessingRun.create!.tap do |record|
      path = Rails.root.join("spec/fixtures/files/input_prueba.xlsx")
      record.input_file.attach(io: File.open(path, "rb"), filename: "input_prueba.xlsx")
    end
  end

  it "processes the supplier workbook, persists results and attaches a six-sheet export" do
    described_class.new(run).call
    run.reload

    expect(run.status).to eq("completed")
    expect(run.processed_records).to eq(5)
    expect(run.processing_records.count).to eq(5)
    expect(run.processing_records.joins(:enrichment_requests)).to be_empty
    expect(run.status).to eq("completed")
    expect(run.output_file).to be_attached
    expect(run.processing_records.first.unresolved).to be_empty
    expect(run.processing_issues).to be_empty
    run.output_file.open do |file|
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      expect(workbook.sheets).to eq(Catalog::WorkbookContract::SHEETS)
      expect(workbook.sheet("Origen").cell(2, 2)).to eq("FSX-5840301")
      expect(workbook.sheet("Aplicaciones").cell(2, 1)).to be_nil
    end
  end

  it "does not duplicate records when invoked again after completion" do
    2.times { described_class.new(run).call }
    expect(run.processing_records.count).to eq(5)
    expect(run.output_file).to be_attached
  end

  it "preserves the row-specific meaning of legacy knowledge releases" do
    release = KnowledgeRelease.create!(entries: [ { "sku" => "FSX-5840301", "brand" => "FRACO", "source_sheet" => "Different", "source_row" => 2,
      "manufacturer" => "Nissan", "model" => "Example", "year" => 2001 } ])
    run.update!(knowledge_release_id: release.id)
    described_class.new(run).call

    expect(run.processing_records.find_by!(source_sku: "FSX-5840301").normalized_product.fetch("applications")).to be_empty
    run.output_file.open do |file|
      expect(Roo::Spreadsheet.open(file.path, extension: :xlsx).sheet("Aplicaciones").cell(2, 1)).to be_nil
    end
  end

  it "does not silently reprocess a run pinned to unavailable earlier rules" do
    run.update!(format_key: "sample_supplier", format_version: "1.0.0", ruleset_version: "1.0.0",
      knowledge_release_id: "empty-v1", export_schema_version: "1.0.0")

    expect { described_class.new(run).call }.to raise_error(Etl::FormatRegistry::UnknownFormat, /Pinned processing versions/)
    expect(run.reload.status).to eq("failed")
    expect(run.output_file).not_to be_attached
  end

  it "keeps a transient failure retryable rather than marking the run terminal" do
    allow_any_instance_of(Etl::Exporters::XlsxExporter).to receive(:call).and_raise(IOError, "temporary failure")

    expect { described_class.new(run).call }.to raise_error(IOError)
    expect(run.reload.status).to eq("queued")
    expect(run.last_error_code).to eq("IOError")
    expect(run).not_to be_terminal
    allow_any_instance_of(Etl::Exporters::XlsxExporter).to receive(:call).and_call_original
    described_class.new(run).call
    expect(run.reload.processing_issues).to be_empty
    expect(run.last_error_code).to be_nil
    expect(run.last_error_message).to be_nil
  end

  it "exports sourced ring dimensions as attributes without inventing fitments" do
    source = ProcessingRun.create!
    path = Rails.root.join("spec/fixtures/files/output_prueba.xlsx")
    source.input_file.attach(io: File.open(path, "rb"), filename: "output_prueba.xlsx")
    described_class.new(source).call

    source.output_file.open do |file|
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      attributes = workbook.sheet("Atributos").each_row_streaming.map { |row| row.map { |cell| cell&.value } }
      expect(attributes).to include(a_collection_including("2C4516+STD", "Diámetro", "mm", 89.0))
      expect(workbook.sheet("Aplicaciones").cell(2, 1)).to be_nil
    end
  end

  it "extracts description candidates and produces catalog rows for the independent input" do
    described_class.new(run).call
    record = run.processing_records.find_by!(source_sku: "FSX-5840301")
    expect(record.facts).to include(a_hash_including("type" => "engine_code_candidate", "value" => "KA24E", "raw_value" => "KA24E", "confidence" => "candidate"))
    expect(record.facts).to include(a_hash_including("type" => "valve_count_candidate", "value" => 12))
    expect(record.facts).to include(a_hash_including("type" => "displacement_liters_candidate", "value" => 2.4))
    expect(record.facts).to include(a_hash_including("type" => "reference_candidate", "value" => "FS-001225"))
    expect(record.facts).to include(a_hash_including("type" => "year_range_candidate", "value" => "89/03"))
    expect(record.facts.first.fetch("source")).to include("sheet" => "Origen", "row" => 2)

    run.output_file.open do |file|
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      catalog = workbook.sheet("Catálogo")
      expect(catalog.row(2).first(7)).to eq([ "FSX-5840301", "FRACO", nil, nil, nil, "JUEGO DE EMPAQUES", record.normalized_product.fetch("description") ])
      expect(catalog.cell(6, 1)).to eq("TK1283-1")
      attributes = workbook.sheet("Atributos").each_row_streaming.map { |row| row.map { |cell| cell&.value } }
      expect(attributes).to include([ "FSX-5840301", "FRACO", "JUEGO DE EMPAQUES", "Número", "Número de válvulas", nil, 12 ])
      expect(workbook.sheet("Aplicaciones").cell(2, 1)).to be_nil
      expect(workbook.sheet("Intercambios").cell(2, 1)).to be_nil
    end
  end

  it "honors a cancellation already requested before processing begins" do
    run.update!(status: "cancel_requested")
    described_class.new(run).call

    expect(run.reload.status).to eq("canceled")
    expect(run.finished_at).to be_present
    expect(run.output_file).not_to be_attached
  end

  it "retains accurate partial record and warning counts on cancellation" do
    allow_any_instance_of(ProcessingRecord).to receive(:update!).and_wrap_original do |method, attributes|
      result = method.call(attributes)
      run.reload.request_cancellation!
      result
    end

    described_class.new(run).call

    expect(run.reload.status).to eq("canceled")
    expect(run.processing_records.count).to eq(1)
    expect(run.processed_records).to eq(1)
    expect(run.warning_records).to eq(0)
  end

  it "checkpoints partial counts when processing is interrupted before a batch finishes" do
    calls = 0
    allow_any_instance_of(ProcessingRecord).to receive(:update!).and_wrap_original do |method, attributes|
      calls += 1
      raise IOError, "temporary failure" if calls == 2

      method.call(attributes)
    end

    expect { described_class.new(run).call }.to raise_error(IOError)
    expect(run.reload.status).to eq("queued")
    expect(run.processed_records).to eq(1)
    expect(run.warning_records).to eq(0)
    expect(run.processing_issues.count).to eq(0)
  end

  it "persists progress while processing larger workbooks" do
    allow_any_instance_of(Etl::Formats::SampleSupplier::Profile).to receive(:each_record) do |_profile, _workbook, &block|
      30.times do |index|
        expect(run.reload.processed_records).to eq(25) if index == 25
        block.call(Automotive::Domain::InputRecord.new(source_identifier: index, sku: "SKU-#{index}", brand_text: "Brand",
          category_text: "Other", description: "", structured_fields: { "source_row" => [ index, "SKU-#{index}" ] },
          metadata: { "sheet" => "Origen", "row" => index + 2 }))
      end
    end

    described_class.new(run).call
    expect(run.reload.processed_records).to eq(30)
    expect(run.warning_records).to eq(0)
  end

  it "does not finalize or expose output when cancellation arrives during export" do
    allow_any_instance_of(Etl::Exporters::XlsxExporter).to receive(:call).and_wrap_original do |method, records|
      bytes = method.call(records)
      run.reload.request_cancellation!
      bytes
    end

    described_class.new(run).call

    expect(run.reload.status).to eq("canceled")
    expect(run.output_file).not_to be_attached
    expect(run.progress_percent).to be < 100
  end

  it "uploads the artifact before marking the run complete" do
    run
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_wrap_original do |method, *args, **options|
      expect(run.reload.status).to eq("processing")
      method.call(*args, **options)
    end

    described_class.new(run).call

    expect(ActiveStorage::Blob).to have_received(:create_and_upload!).at_least(:once)
    expect(run.reload.status).to eq("completed")
    expect(run.output_file).to be_attached
  end

  it "does not publish an uploaded artifact if cancellation arrives during the upload" do
    run
    uploaded_id = nil
    allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_wrap_original do |method, *args, **options|
      blob = method.call(*args, **options)
      uploaded_id = blob.id
      run.reload.request_cancellation!
      blob
    end

    described_class.new(run).call

    expect(run.reload.status).to eq("canceled")
    expect(run.output_file).not_to be_attached
    expect(ActiveStorage::Blob.exists?(uploaded_id)).to be(false)
  end

  it "preserves cancellation when profile detection fails at the same time" do
    allow_any_instance_of(Etl::FormatRegistry).to receive(:resolve) do
      run.reload.request_cancellation!
      raise Etl::FormatRegistry::UnknownFormat, "invalid profile"
    end

    expect { described_class.new(run).call }.not_to raise_error
    expect(run.reload.status).to eq("canceled")
    expect(run.output_file).not_to be_attached
  end
end
