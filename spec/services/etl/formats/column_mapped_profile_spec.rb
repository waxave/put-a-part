require "rails_helper"
require "axlsx"
require "roo"

RSpec.describe "Column-mapped XLSX profile" do
  def workbook_bytes(include_original: false)
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Products") do |sheet|
      sheet.add_row [ "Brand", "Part Number", "Description", "Category", "Supplier ID", "Unit", "Notes" ]
      sheet.add_row [ "HASTING", "2C4516+STD", "QR25DE 89X1.2X1.2X2", "ANILLOS", "A-10", "SET", "Original supplier note" ]
    end
    if include_original
      package.workbook.add_worksheet(name: "Origen") { |sheet| sheet.add_row Catalog::WorkbookContract::HEADERS.fetch("Origen") }
    end
    package.to_stream.read
  end

  it "detects a distinct layout and maps it through the shared pipeline without losing original fields" do
    run = ProcessingRun.create!
    run.input_file.attach(io: StringIO.new(workbook_bytes), filename: "supplier.xlsx")
    Etl::Pipeline.new(run).call

    expect(run.reload).to have_attributes(format_key: "column_mapped", format_version: "1.0.0", status: "completed")
    record = run.processing_records.sole
    expect(record).to have_attributes(source_sheet: "Products", source_row: 2, source_sku: "2C4516+STD")
    expect(record.normalized_product.fetch("source_fields")).to include("Notes" => "Original supplier note", "Brand" => "HASTING")
    expect(record.facts).to include(a_hash_including("type" => "ring_dimensions", "source" => a_hash_including("sheet" => "Products", "row" => 2)))
    run.output_file.open do |file|
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      expect(workbook.sheet("Origen").row(2).first(7)).to eq([ "A-10", "2C4516+STD", nil, "QR25DE 89X1.2X1.2X2", "ANILLOS", "HASTING", "SET" ])
      expect(workbook.sheet("Aplicaciones").cell(2, 1)).to be_nil
    end
  end

  it "reports ambiguous formats and permits an explicitly selected matching profile" do
    Tempfile.create([ "profiles", ".xlsx" ]) do |file|
      file.binmode
      file.write(workbook_bytes(include_original: true))
      file.flush
      workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
      registry = Etl::FormatRegistry.new
      expect { registry.resolve(workbook) }.to raise_error(Etl::FormatRegistry::AmbiguousFormat)
      expect(registry.resolve(workbook, key: "column_mapped").class::KEY).to eq("column_mapped")
      expect(registry.resolve(workbook, key: "sample_supplier").class::KEY).to eq("sample_supplier")
    end
  end

  it "rejects missing or duplicate headers instead of guessing a column mapping" do
    profile = Etl::Formats::ColumnMapped::Profile
    [ [ "Brand", "Part Number", "Description", "Category", "Unit" ],
      [ "Brand", "Part Number", "Description", "Category", "Supplier ID", "Unit", "Brand" ] ].each do |headers|
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Products") { |sheet| sheet.add_row(headers) }
      Tempfile.create([ "invalid-profile", ".xlsx" ]) do |file|
        file.binmode
        file.write(package.to_stream.read)
        file.flush
        expect(profile.detect?(Roo::Spreadsheet.open(file.path, extension: :xlsx))).to be(false)
      end
    end
  end
end
