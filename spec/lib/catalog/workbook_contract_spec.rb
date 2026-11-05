require "roo"
require "json"
require_relative "../../../lib/catalog/workbook_contract"

RSpec.describe Catalog::WorkbookContract do
  let(:fixtures) { File.expand_path("../../fixtures/files", __dir__) }

  [ "input_prueba.xlsx", "output_prueba.xlsx" ].each do |filename|
    context filename do
      let(:workbook) { Roo::Spreadsheet.open(File.join(fixtures, filename)) }

      it "has the expected sheets, table headers and metric labels" do
        expect(workbook.sheets).to eq(described_class::SHEETS)
        described_class::HEADERS.each do |name, headers|
          actual = workbook.sheet(name).row(1).reverse.drop_while(&:nil?).reverse
          expect(actual).to eq(headers)
        end
        described_class::METRIC_LABELS.each do |row, label|
          expect(workbook.sheet("Métricas").cell(row, 1)).to eq(label)
        end
      end
    end
  end

  it "records populated reference rows and metric formulae without counting formatted empty rows" do
    workbook = Roo::Spreadsheet.open(File.join(fixtures, "output_prueba.xlsx"))
    counts = { "Origen" => 10, "Aplicaciones" => 2610, "Intercambios" => 31, "Atributos" => 74, "Catálogo" => 10 }

    counts.each do |name, expected|
      sheet = workbook.sheet(name)
      actual = sheet.each_row_streaming.drop(1).count { |row| row.any? { |cell| !cell&.value.nil? } }
      expect(actual).to eq(expected), name
    end

    metrics = workbook.sheet("Métricas")
    expect([ metrics.cell(2, 2), metrics.cell(4, 2), metrics.cell(8, 2), metrics.cell(12, 2) ]).to eq([ 10, 2610, 31, 74 ])
    expect([ metrics.formula(6, 2), metrics.formula(10, 2), metrics.formula(14, 2) ]).to eq([ "B4-B5", "B8-B9", "B12-B13" ])
  end

  it "joins the reference output sheets to source references without unmatched products" do
    workbook = Roo::Spreadsheet.open(File.join(fixtures, "output_prueba.xlsx"))
    source_rows = populated_rows(workbook.sheet("Origen"))
    references = source_rows.map { |row| row[1] }
    expect(references.uniq.length).to eq(10)

    [ "Aplicaciones", "Intercambios", "Atributos", "Catálogo" ].each do |name|
      rows = populated_rows(workbook.sheet(name))
      expect(rows.map(&:first).uniq - references).to be_empty, name
      expect(rows.map(&:first).uniq.sort).to eq(references.sort), name
    end
  end

  it "ties representative candidate facts to their exact source cells" do
    workbook = Roo::Spreadsheet.open(File.join(fixtures, "output_prueba.xlsx"))
    source = workbook.sheet("Origen")
    cases = JSON.parse(File.read(File.join(fixtures, "canonical_reference_cases.json")))

    cases.each do |example|
      location = example.fetch("source")
      row = location.fetch("row")
      expect(source.cell(row, 2)).to eq(location.fetch("sku"))
      expect(source.cell(row, 6)).to eq(location.fetch("brand"))
      example.fetch("candidate_facts").each do |fact|
        source_text = source.cell(row, fact.fetch("type") == "variant" ? 2 : 4)
        expect(source_text).to include(fact.fetch("raw_value"))
      end
    end
  end

  def populated_rows(sheet)
    sheet.each_row_streaming(pad_cells: true).filter_map do |cells|
      next if cells.compact.first&.coordinate&.row == 1

      values = cells.map { |cell| cell&.value }
      values if values.any? { |value| !value.nil? }
    end
  end
end
