require "rails_helper"
require "roo"
require Rails.root.join("lib/catalog/workbook_contract")

RSpec.describe Etl::Exporters::XlsxExporter do
  it "exports source-backed catalog rows without claiming unresolved taxonomy" do
    product = { "sku" => "X-123", "brand" => "Supplier Brand", "category" => "BOMBA DE ACEITE",
                "description" => "NISSAN 4 CIL KA24DE", "source_row" => [ 1, "X-123" ] }
    record = instance_double(ProcessingRecord, normalized_product: product, facts: [])
    bytes = described_class.new.call([ record ])

    Tempfile.create([ "catalog", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      sheet = Roo::Spreadsheet.open(file.path).sheet("Catálogo")
      expect(sheet.row(2).first(7)).to eq([ "X-123", "Supplier Brand", nil, nil, nil, "BOMBA DE ACEITE", "NISSAN 4 CIL KA24DE" ])
    end
  end

  it "treats supplier values that begin with an equals sign as text, not formulas" do
    product = { "sku" => "=1+1", "brand" => "Brand", "category" => "Parts",
                "description" => "=2+2", "source_row" => [ 1, "=1+1" ] }
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: []) ])

    Tempfile.create([ "catalog", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      sheet = Roo::Spreadsheet.open(file.path).sheet("Catálogo")
      expect(sheet.formula(2, 1)).to be_nil
      expect(sheet.formula(2, 7)).to be_nil
    end
  end

  it "exports explicitly stated product attributes and updates metrics" do
    product = { "sku" => "FSX-5840301", "brand" => "FRACO", "category" => "JUEGO DE EMPAQUES",
                "description" => "KA24E 12 VAL", "source_row" => [ 1, "FSX-5840301" ] }
    fact = { "type" => "source_product_attribute", "confidence" => "supplier_asserted",
             "value" => { "class" => "Número", "name" => "Número de válvulas", "unit" => nil, "value" => 12 } }
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: [ fact ]) ])

    Tempfile.create([ "catalog", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      workbook = Roo::Spreadsheet.open(file.path)
      expect(workbook.sheet("Atributos").row(2).first(7)).to eq([ "FSX-5840301", "FRACO", "JUEGO DE EMPAQUES", "Número", "Número de válvulas", nil, 12 ])
      expect(workbook.sheet("Métricas").cell(12, 2)).to eq(1)
    end
  end

  it "exports candidate facts through the Spanish catalog and excludes vehicle and unknown facts" do
    product = { "sku" => "X-1", "brand" => "FRACO", "category" => "MOTOR", "source_row" => [ 1, "X-1" ] }
    facts = [
      { "type" => "engine_code_candidate", "confidence" => "candidate", "value" => "KA24E", "raw_value" => "KA24E" },
      { "type" => "cylinder_count_candidate", "confidence" => "candidate", "value" => 4 },
      { "type" => "vehicle_candidate", "confidence" => "candidate", "value" => { "make" => "Nissan" } },
      { "type" => "future_unknown_candidate", "confidence" => "candidate", "value" => "unknown" }
    ]
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: facts) ])

    Tempfile.create([ "catalog-attributes", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      rows = Roo::Spreadsheet.open(file.path).sheet("Atributos").each_row_streaming.map { |row| row.map { |cell| cell&.value } }
      data_rows = rows.drop(1).select { |row| row.first.present? }
      expect(data_rows.map { |row| row.values_at(3, 4, 6) }).to eq([
        [ "Motor", "Código de motor", "KA24E" ], [ "Número", "Número de cilindros", 4 ]
      ])
      expect(rows.flatten).not_to include("Candidato", "Vehicle", "Nissan", "future_unknown_candidate")
    end
  end

  it "fails explicitly when a required versioned attribute definition is missing" do
    product = { "sku" => "X-1", "brand" => "FRACO", "category" => "MOTOR", "source_row" => [ 1, "X-1" ] }
    fact = { "type" => "engine_code_candidate", "confidence" => "candidate", "value" => "KA24E" }
    AttributeDefinition.find_by!(catalog_key: "engine_code", source_version: described_class::ATTRIBUTE_CATALOG_VERSION).destroy!

    expect do
      described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: [ fact ]) ])
    end.to raise_error(described_class::MissingAttributeDefinitions, /engine_code/)
  end

  it "omits conflicting values and collapses duplicate extractions" do
    product = { "sku" => "X-2", "brand" => "FRACO", "category" => "MOTOR", "source_row" => [ 1, "X-2" ] }
    facts = [
      { "type" => "engine_code_candidate", "confidence" => "candidate", "value" => "KA24E" },
      { "type" => "engine_code_candidate", "confidence" => "candidate", "value" => "KA24E" },
      { "type" => "cylinder_count_candidate", "confidence" => "candidate", "value" => 4 },
      { "type" => "cylinder_count_candidate", "confidence" => "candidate", "value" => 6 }
    ]
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: facts) ])

    Tempfile.create([ "catalog-conflicts", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      rows = Roo::Spreadsheet.open(file.path).sheet("Atributos").each_row_streaming.map { |row| row.map { |cell| cell&.value } }
      data_rows = rows.drop(1).select { |row| row.first.present? }
      expect(data_rows.map { |row| row.values_at(4, 6) }).to eq([ [ "Código de motor", "KA24E" ] ])
    end
  end

  it "preserves numeric-looking reviewed attribute values and part numbers as text" do
    product = { "sku" => "00123", "brand" => "BRAND", "category" => "Parts", "description" => "", "source_row" => [ 1, "00123" ],
      "attributes" => [ { "attribute_class" => "Motor", "name" => "Código de motor", "unit" => nil, "value" => "00123" } ] }
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: []) ])
    Tempfile.create([ "catalog", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      workbook = Roo::Spreadsheet.open(file.path)
      expect(workbook.sheet("Atributos").row(2).first(7)).to eq([ "00123", "BRAND", "Parts", "Motor", "Código de motor", nil, "00123" ])
      expect(workbook.sheet("Catálogo").cell(2, 1)).to eq("00123")
      expect(workbook.sheet("Origen").cell(2, 2)).to eq("00123")
    end
  end

  it "uses the supplied template while preserving its formula, filters, merged cells and header styling" do
    product = { "sku" => "00123", "brand" => "Brand", "category" => "Parts", "description" => "QR25DE 4 CIL 2.5L 2002/05",
      "source_row" => [ "ID", "00123", nil, "QR25DE 4 CIL 2.5L 2002/05", "Parts", "Brand", "EA" ] }
    facts = Automotive::Parsers::DescriptionParser.call(product.fetch("description")).map do |fact|
      fact.stringify_keys.merge("confidence" => "candidate")
    end
    bytes = described_class.new.call([ instance_double(ProcessingRecord, normalized_product: product, facts: facts) ])

    Tempfile.create([ "catalog-template", ".xlsx" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      workbook = RubyXL::Parser.parse(file.path)
      expect(workbook.worksheets.map(&:sheet_name)).to eq(Catalog::WorkbookContract::SHEETS)
      expect(workbook[1].sheet_data[13][1].formula.expression).to eq("B12-B13")
      expect(workbook[1].merged_cells.map(&:ref).map(&:to_s)).to include("A1:B1")
      expect(workbook[2].auto_filter.ref.to_s).to eq("A1:O1")
      expect(workbook[3].auto_filter.ref.to_s).to eq("A1:F1")
      expect(workbook[4].auto_filter.ref.to_s).to eq("A1:G4")
      expect(workbook[5].auto_filter.ref.to_s).to eq("A1:G2")
      expect(workbook[4].sheet_data[1][3].value).to eq("Motor")
      expect(workbook[4].sheet_data[1][4].value).to eq("Código de motor")
      expect(workbook[4].sheet_data[1][6].value).to eq("QR25DE")
      expect(workbook[4].sheet_data[1][0].style_index).to eq(15)
      expect(workbook[2].sheet_data[0][0].style_index).to eq(9)
      expect(workbook.calc_pr.full_calc_on_load).to be(true)
      expect(workbook.calc_pr.force_full_calc).to be(true)
    end
  end
end
