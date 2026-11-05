require "rubyXL"
require "digest"
require "tempfile"

module Etl
  module Exporters
    class XlsxExporter
      SCHEMA_VERSION = "2.1.0"
      ATTRIBUTE_CATALOG_VERSION = "attribute-catalog-v1"
      TEMPLATE_PATH = Rails.root.join("lib/catalog/output_template.xlsx").freeze
      TEMPLATE_SHA256 = "b50eae4454888929293fe93a4c53e6f068f0e18be4d7722c118a822090fc0a37".freeze
      SHEET_WIDTHS = { "Aplicaciones" => 15, "Intercambios" => 6, "Atributos" => 7, "Catálogo" => 7 }.freeze

      def call(records)
        validate_template!
        workbook = RubyXL::Parser.parse(TEMPLATE_PATH.to_s)
        sheets = workbook.worksheets.index_by(&:sheet_name)
        assert_template_contract!(sheets)

        attributes = attribute_rows(records)
        applications = application_rows(records)
        interchanges = interchange_rows(records)
        catalog = catalog_rows(records)
        source = records.map { |record| record.normalized_product.fetch("source_row") }

        write_rows(sheets.fetch("Origen"), source, 7)
        write_rows(sheets.fetch("Aplicaciones"), applications, SHEET_WIDTHS.fetch("Aplicaciones"))
        write_rows(sheets.fetch("Intercambios"), interchanges, SHEET_WIDTHS.fetch("Intercambios"))
        write_rows(sheets.fetch("Atributos"), attributes, SHEET_WIDTHS.fetch("Atributos"))
        write_rows(sheets.fetch("Catálogo"), catalog, SHEET_WIDTHS.fetch("Catálogo"))
        resize_filter(sheets.fetch("Aplicaciones"), 15, applications.length)
        resize_filter(sheets.fetch("Intercambios"), 6, interchanges.length)
        resize_filter(sheets.fetch("Atributos"), 7, attributes.length)
        resize_filter(sheets.fetch("Catálogo"), 7, catalog.length)
        update_metrics(sheets.fetch("Métricas"), records.length, applications.length, interchanges.length, attributes.length)
        workbook.calc_pr.full_calc_on_load = true
        workbook.calc_pr.force_full_calc = true

        Tempfile.create([ "catalog-", ".xlsx" ]) do |file|
          workbook.write(file.path)
          File.binread(file.path)
        end
      end

      private

      def validate_template!
        actual = Digest::SHA256.file(TEMPLATE_PATH).hexdigest
        raise "Export template checksum mismatch" unless actual == TEMPLATE_SHA256
      end

      def assert_template_contract!(sheets)
        expected = Catalog::WorkbookContract::SHEETS
        raise "Export template worksheets do not match the workbook contract" unless sheets.keys == expected

        expected.each do |name|
          next if name == "Métricas"

          headers = sheets.fetch(name).sheet_data[0].cells.first(Catalog::WorkbookContract::HEADERS.fetch(name).length).map(&:value)
          raise "Export template headers do not match for #{name}" unless headers == Catalog::WorkbookContract::HEADERS.fetch(name)
        end
      end

      def write_rows(sheet, rows, width)
        rows.each_with_index do |values, offset|
          values = values.first(width).fill(nil, values.length...width)
          values.each_with_index do |value, column|
            row = offset + 1
            write_cell(sheet, row, column, safe_value(value))
          end
        end
        # Clear any pre-existing template body values beyond the newly written rows.
        ((rows.length + 1)...sheet.sheet_data.rows.length).each do |row_index|
          row = sheet.sheet_data[row_index]
          next unless row

          width.times do |column|
            cell = row.cells[column]
            write_cell(sheet, row_index, column, nil) if cell && cell.value
          end
        end
      end

      def write_cell(sheet, row, column, value)
        existing = sheet.sheet_data[row]&.cells&.[](column)
        template = sheet.sheet_data[1]&.cells&.[](column)
        style_index = existing&.style_index || template&.style_index
        cell = sheet.add_cell(row, column, value, nil, true)
        cell.style_index = style_index if style_index
      end

      def safe_value(value)
        value.is_a?(String) ? value : value
      end

      def resize_filter(sheet, width, data_rows)
        sheet.auto_filter.ref = RubyXL::Reference.new("A1:#{column_name(width)}#{data_rows + 1}")
      end

      def column_name(number)
        result = +""
        while number.positive?
          number, remainder = (number - 1).divmod(26)
          result.prepend((65 + remainder).chr)
        end
        result
      end

      def update_metrics(sheet, source_count, application_count, interchange_count, attribute_count)
        { 1 => "Catálogo Bonaparte - Refaccionaria Trópico de Cáncer", 4 => "Aplicaciones", 5 => "Origen",
          6 => "Incrementos", 8 => "Intercambios", 9 => "Origen", 10 => "Incrementos", 12 => "Atributos",
          13 => "Origen" }.each { |row, value| sheet.add_cell(row - 1, 0, value, nil, true) }
        sheet.add_cell(1, 0, "Referencias:", nil, true)
        sheet.add_cell(4, 1, source_count, nil, true)
        sheet.add_cell(5, 1, 0, nil, true)
        sheet.add_cell(8, 1, 0, nil, true)
        sheet.add_cell(11, 1, attribute_count, nil, true)
        sheet.add_cell(12, 1, 0, nil, true)
        # Keep the template's B14 formula; it calculates attribute increments.
        sheet.add_cell(3, 1, application_count, nil, true)
        sheet.add_cell(7, 1, interchange_count, nil, true)
      end

      def application_rows(records)
        records.flat_map do |record|
          product = record.normalized_product
          product.fetch("applications", []).map do |entry|
            [ product["sku"], product["brand"], product["category"], nil, entry["manufacturer"], entry["model"], nil, entry["year"],
              entry.dig("qualifiers", "liters"), entry.dig("qualifiers", "cc"), entry.dig("qualifiers", "cid"),
              entry.dig("qualifiers", "cylinders"), entry.dig("qualifiers", "block"), entry.dig("qualifiers", "fuel"), entry.dig("qualifiers", "market") ]
          end
        end
      end

      def interchange_rows(records)
        records.flat_map do |record|
          product = record.normalized_product
          product.fetch("interchanges", []).map do |entry|
            [ product["sku"], product["brand"], product["category"], entry["interchange_reference"], entry["interchange_brand"], entry["source_key"] ]
          end
        end
      end

      def catalog_rows(records)
        records.map do |record|
          product = record.normalized_product
          fields = product.fetch("catalog_fields", {})
          [ product["sku"], product["brand"], fields.dig("category", "value"), fields.dig("system", "value"),
            fields.dig("subsystem", "value"), product["category"].presence || fields.dig("product", "value"),
            product["description"].presence || fields.dig("description", "value") ]
        end
      end

      def attribute_rows(records)
        pending = records.flat_map do |record|
          product = record.normalized_product
          prefix = [ product["sku"], product["brand"], product["category"] ]
          extracted = record.facts.flat_map { |fact| attribute_facts(fact).map { |key, value| [ prefix, key, value ] } }
          reviewed = product.fetch("attributes", []).filter_map do |attribute|
            key = catalog_key_for_name(attribute["name"])
            [ prefix, key, attribute["value"] ] if key
          end
          extracted + reviewed
        end

        definitions = AttributeDefinition.where(catalog_key: pending.map { |_, key, _| key }.uniq,
          source_version: ATTRIBUTE_CATALOG_VERSION).index_by(&:catalog_key)
        pending.select { |_, key, value| definitions.key?(key) && !value.nil? }.group_by { |prefix, key, _| [ prefix, key ] }.filter_map do |(prefix, key), entries|
          values = entries.map(&:last).uniq
          next unless values.one?

          definition = definitions.fetch(key)
          prefix + [ definition.attribute_class, definition.name, definition.default_unit, values.first ]
        end
      end

      def attribute_facts(fact)
        case fact["type"]
        when "engine_code_candidate"
          [ [ "engine_code", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "engine_family_candidate"
          [ [ "engine_family", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "cylinder_count_candidate"
          [ [ "cylinder_count", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "displacement_liters_candidate"
          [ [ "displacement_liters", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "valve_count_candidate"
          [ [ "valve_count", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "camshaft_candidate"
          [ [ "camshaft_type", fact["value"] ] ] if fact["confidence"] == "candidate"
        when "source_product_attribute"
          return [] unless fact["confidence"] == "supplier_asserted"

          value = fact["value"] || {}
          key = { "Número de válvulas" => "valve_count", "Diámetro" => "diameter",
                  "Junta Cabeza" => "gasket_material", "Dientes" => "tooth_count" }[value["name"]]
          key ? [ [ key, value["value"] ] ] : []
        when "ring_dimensions"
          value = fact["value"] || {}
          [ [ "ring_diameter", value["diameter_mm"] ] ] + Array(value["ring_widths_mm"]).each_with_index.map do |width, index|
            [ "ring_width_#{index + 1}", width ]
          end
        else
          []
        end
      end

      def catalog_key_for_name(name)
        {
          "Código de motor" => "engine_code", "Familia de motor" => "engine_family",
          "Número de cilindros" => "cylinder_count", "Cilindrada" => "displacement_liters",
          "Número de válvulas" => "valve_count", "Tipo de árbol de levas" => "camshaft_type",
          "Diámetro" => "diameter", "Material de junta de culata" => "gasket_material",
          "Número de dientes" => "tooth_count"
        }[name]
      end
    end
  end
end
