require "roo"

module Etl
  module Formats
    module SampleSupplier
      class Profile
        KEY = "sample_supplier"
        VERSION = "1.0.0"

        def self.detect?(workbook)
          return false unless workbook.sheets.include?("Origen")

          workbook.sheet("Origen").row(1).first(7) == Catalog::WorkbookContract::HEADERS.fetch("Origen")
        end

        def each_record(workbook)
          workbook.sheet("Origen").each_row_streaming(pad_cells: true) do |cells|
            row_number = cells.compact.first&.coordinate&.row
            next unless row_number && row_number > 1

            values = cells.first(7).map { |cell| cell&.value }
            next if values.all?(&:nil?)

            yield Automotive::Domain::InputRecord.new(
              source_identifier: values[0], sku: values[1], brand_text: values[5], category_text: values[4],
              description: values[3], structured_fields: { "source_row" => values },
              metadata: { "sheet" => "Origen", "row" => row_number }
            )
          end
        end
      end
    end
  end
end
