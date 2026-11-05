module Etl
  module Formats
    module ColumnMapped
      # An explicit generic layout, not an assertion about any specific supplier.
      class Profile
        KEY = "column_mapped"
        VERSION = "1.0.0"
        SHEET = "Products"
        REQUIRED_HEADERS = [ "Brand", "Part Number", "Description", "Category", "Supplier ID", "Unit" ].freeze

        def self.detect?(workbook)
          return false unless workbook.sheets.include?(SHEET)

          headers = workbook.sheet(SHEET).row(1).compact
          headers.uniq.length == headers.length && (REQUIRED_HEADERS - headers).empty?
        end

        def each_record(workbook)
          sheet = workbook.sheet(SHEET)
          headers = sheet.row(1)
          sheet.each_row_streaming(pad_cells: true) do |cells|
            row_number = cells.compact.first&.coordinate&.row
            next unless row_number && row_number > 1

            values = cells.map { |cell| cell&.value }
            next if values.all?(&:nil?)

            fields = headers.each_with_index.to_h { |header, index| [ header, values[index] ] }.except(nil)
            canonical_row = [ fields["Supplier ID"], fields["Part Number"], nil, fields["Description"], fields["Category"], fields["Brand"], fields["Unit"] ]
            yield Automotive::Domain::InputRecord.new(
              source_identifier: fields["Supplier ID"], sku: fields["Part Number"], brand_text: fields["Brand"], category_text: fields["Category"],
              description: fields["Description"], structured_fields: { "source_row" => canonical_row, "source_fields" => fields },
              metadata: { "sheet" => SHEET, "row" => row_number }
            )
          end
        end
      end
    end
  end
end
