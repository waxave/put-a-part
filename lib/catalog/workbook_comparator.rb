require "roo"
require_relative "workbook_contract"

module Catalog
  # Compares logical cell values, preserving duplicate rows but ignoring their order.
  # Formatting, formulas and row order are intentionally outside this first comparator.
  class WorkbookComparator
    # Conservative comparison keys, not assertions of universal identity.
    # Ambiguous or duplicate keys fall back to multiset differences.
    PRODUCT_KEY_COLUMNS = {
      "Origen" => [ 1, 5 ], "Catálogo" => [ 0, 1 ],
      "Aplicaciones" => [ 0, 1, 4, 5, 7 ], "Intercambios" => [ 0, 1, 3, 4 ],
      "Atributos" => [ 0, 1, 3, 4 ]
    }.freeze

    def compare(expected_path, actual_path)
      expected = Roo::Spreadsheet.open(expected_path)
      actual = Roo::Spreadsheet.open(actual_path)
      differences = []

      if expected.sheets != actual.sheets
        differences << { type: :sheets, expected: expected.sheets, actual: actual.sheets }
      end

      (expected.sheets & actual.sheets).each do |name|
        expected_sheet = expected.sheet(name)
        actual_sheet = actual.sheet(name)

        if name == "Métricas"
          compare_metrics(expected_sheet, actual_sheet, differences)
        else
          compare_table(name, expected_sheet, actual_sheet, differences)
        end
      end

      differences
    end

    private

    def compare_table(name, expected, actual, differences)
      expected_header = header(expected)
      actual_header = header(actual)
      if expected_header != actual_header
        differences << { type: :headers, sheet: name, expected: expected_header, actual: actual_header }
      end

      expected_rows = row_counts(expected)
      actual_rows = row_counts(actual)
      compare_unique_products(name, expected_header, expected_rows, actual_rows, differences)
      (expected_rows.keys | actual_rows.keys).each do |row|
        expected_count = expected_rows.fetch(row, 0)
        actual_count = actual_rows.fetch(row, 0)
        next if expected_count == actual_count

        differences << { type: :row_count, sheet: name, row: row, expected: expected_count, actual: actual_count }
      end
    end

    def compare_unique_products(name, headers, expected_rows, actual_rows, differences)
      columns = PRODUCT_KEY_COLUMNS[name]
      return unless columns

      expected_groups = group_by_product(expected_rows, columns)
      actual_groups = group_by_product(actual_rows, columns)
      (expected_groups.keys & actual_groups.keys).each do |key|
        expected_group = expected_groups.fetch(key)
        actual_group = actual_groups.fetch(key)
        next unless expected_group.size == 1 && actual_group.size == 1

        expected_row = expected_group.first
        actual_row = actual_group.first
        next unless expected_rows[expected_row] == 1 && actual_rows[actual_row] == 1
        next if expected_row == actual_row

        [ expected_row.length, actual_row.length ].max.times do |index|
          next if expected_row[index] == actual_row[index]

          differences << { type: :field, sheet: name, product_key: key, column: headers[index] || index + 1,
                           expected: expected_row[index], actual: actual_row[index] }
        end
        expected_rows.delete(expected_row)
        actual_rows.delete(actual_row)
      end
    end

    def group_by_product(rows, columns)
      rows.keys.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |row, groups|
        key = columns.map { |column| row[column] }
        groups[key] << row unless key.any? { |value| value.nil? || value == "" }
      end
    end

    def row_counts(sheet)
      counts = Hash.new(0)
      sheet.each_row_streaming(pad_cells: true) do |cells|
        next if cells.compact.first&.coordinate&.row == 1

        row = trim(cells.map { |cell| cell&.value })
        counts[row] += 1 unless row.empty?
      end
      counts
    end

    def compare_metrics(expected, actual, differences)
      expected_rows = metric_rows(expected)
      actual_rows = metric_rows(actual)
      (expected_rows.keys | actual_rows.keys).sort.each do |number|
        expected_row = expected_rows.fetch(number, [])
        actual_row = actual_rows.fetch(number, [])
        next if expected_row == actual_row

        differences << { type: :metric, sheet: "Métricas", row: number, expected: expected_row, actual: actual_row }
      end
    end

    def header(sheet)
      cells = sheet.each_row_streaming(pad_cells: true, max_rows: 1).first || []
      trim(cells.map { |cell| cell&.value })
    end

    def metric_rows(sheet)
      rows = {}
      sheet.each_row_streaming(pad_cells: true) do |cells|
        number = cells.compact.first&.coordinate&.row
        values = trim(cells.map { |cell| cell&.value })
        rows[number] = values if number && !values.empty?
      end
      rows
    end

    def trim(row)
      result = row.dup
      result.pop while !result.empty? && result.last.nil?
      result
    end
  end
end
