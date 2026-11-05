require_relative "../../../lib/catalog/workbook_comparator"
require "axlsx"
require "tempfile"

RSpec.describe Catalog::WorkbookComparator do
  let(:fixtures) { File.expand_path("../../fixtures/files", __dir__) }
  let(:input) { File.join(fixtures, "input_prueba.xlsx") }
  let(:output) { File.join(fixtures, "output_prueba.xlsx") }

  it "finds no logical differences when comparing a workbook with itself" do
    expect(described_class.new.compare(output, output)).to be_empty
  end

  it "reports differences between independent examples" do
    differences = described_class.new.compare(input, output)
    expect(differences).to include(a_hash_including(type: :metric, sheet: "Métricas", row: 2))
    expect(differences).to include(a_hash_including(type: :row_count, sheet: "Aplicaciones", expected: 0, actual: 1))
  end

  it "preserves legitimate duplicates while ignoring blank formatted rows" do
    cell = ->(value, row) { double(value: value, coordinate: double(row: row)) }
    rows = [ [ cell.call("Header", 1) ], [ cell.call("SKU", 2), cell.call("value", 2), nil ],
             [ cell.call("SKU", 3), cell.call("value", 3) ], [ nil, nil ], [ cell.call("another", 5), nil ] ]
    sheet = double
    allow(sheet).to receive(:each_row_streaming).with(pad_cells: true)
      .and_yield(rows[0]).and_yield(rows[1]).and_yield(rows[2]).and_yield(rows[3]).and_yield(rows[4])

    expect(described_class.new.send(:row_counts, sheet)).to eq({ [ "SKU", "value" ] => 2, [ "another" ] => 1 })
  end

  it "reports field changes for an unambiguous product identity" do
    expected = { [ "SKU", "Brand", "Old" ] => 1 }
    actual = { [ "SKU", "Brand", "New" ] => 1 }
    differences = []

    described_class.new.send(:compare_unique_products, "Catálogo", [ "Referencia", "Marca", "Categoría" ], expected, actual, differences)

    expect(differences).to eq([ { type: :field, sheet: "Catálogo", product_key: [ "SKU", "Brand" ],
                                  column: "Categoría", expected: "Old", actual: "New" } ])
    expect(expected).to be_empty
    expect(actual).to be_empty
  end

  it "does not guess how duplicate product identities should pair" do
    expected = { [ "SKU", "Brand", "Old" ] => 2 }
    actual = { [ "SKU", "Brand", "New" ] => 1 }
    differences = []

    described_class.new.send(:compare_unique_products, "Catálogo", [], expected, actual, differences)

    expect(differences).to be_empty
    expect(expected.values).to eq([ 2 ])
    expect(actual.values).to eq([ 1 ])
  end

  it "reports unambiguous field differences in applications, interchanges and attributes" do
    cases = [
      [ "Aplicaciones", [ "SKU", "Brand", "Pump", nil, "Nissan", "Altima", nil, 2003, 2.4 ],
        [ "SKU", "Brand", "Pump", nil, "Nissan", "Altima", nil, 2003, 2.5 ], 8, "Litros" ],
      [ "Intercambios", [ "SKU", "Brand", "Pump", "ALT-1", "Other", "Old" ],
        [ "SKU", "Brand", "Pump", "ALT-1", "Other", "New" ], 5, "Origen" ],
      [ "Atributos", [ "SKU", "Brand", "Ring", "Diámetro", "Diámetro", "mm", 89 ],
        [ "SKU", "Brand", "Ring", "Diámetro", "Diámetro", "mm", 90 ], 6, "Valor" ]
    ]
    cases.each do |sheet, expected_row, actual_row, index, column|
      expected = { expected_row => 1 }
      actual = { actual_row => 1 }
      differences = []
      headers = Array.new(expected_row.length) { |i| i == index ? column : "Field #{i}" }
      described_class.new.send(:compare_unique_products, sheet, headers, expected, actual, differences)
      expect(differences).to contain_exactly(a_hash_including(type: :field, sheet: sheet, column: column, expected: expected_row[index], actual: actual_row[index]))
      expect(expected).to be_empty
      expect(actual).to be_empty
    end
  end

  it "does not pair ambiguous application configurations sharing the comparison key" do
    first = [ "SKU", "Brand", "Pump", nil, "Nissan", "Altima", nil, 2003, 2.4 ]
    second = first.dup.tap { |row| row[8] = 2.5 }
    expected = { first => 1, second => 1 }
    actual = { first => 1, second.dup.tap { |row| row[8] = 3.0 } => 1 }
    differences = []
    described_class.new.send(:compare_unique_products, "Aplicaciones", [], expected, actual, differences)
    expect(differences).to be_empty
    expect(expected.size).to eq(2)
    expect(actual.size).to eq(2)
  end

  it "identifies an application field difference in actual workbooks" do
    headers = Catalog::WorkbookContract::HEADERS.fetch("Aplicaciones")
    Tempfile.create([ "expected", ".xlsx" ]) do |expected_file|
      Tempfile.create([ "actual", ".xlsx" ]) do |actual_file|
        [ [ expected_file, 2.4 ], [ actual_file, 2.5 ] ].each do |file, liters|
          package = Axlsx::Package.new
          package.workbook.add_worksheet(name: "Aplicaciones") do |sheet|
            sheet.add_row headers
            sheet.add_row [ "SKU", "Brand", "Pump", nil, "Nissan", "Altima", nil, 2003, liters ]
          end
          file.binmode
          file.write(package.to_stream.read)
          file.flush
        end
        expect(described_class.new.compare(expected_file.path, actual_file.path)).to contain_exactly(
          a_hash_including(type: :field, sheet: "Aplicaciones", column: "Litros", expected: 2.4, actual: 2.5)
        )
      end
    end
  end
end
