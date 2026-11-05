module Automotive
  module Parsers
    # Conservative supplier assertions, not externally verified specifications.
    class ProductAttributeParser < Automotive::ServiceBase
      VALVES = /\b(\d{1,2})\s*(?:VAL(?:VULAS?)?|V)\b/i
      DIAMETER = /\b(\d+(?:\.\d+)?)\s*MM\b/i
      GASKET_MATERIAL = /\b(?:CAB|CABEZA|JUNTA)\b.{0,12}\b(MLS)\b/i
      TEETH = /\b(\d{1,4})\s*DIENTES\b/i

      def call(category:, description:)
        text = description.to_s
        case category.to_s.strip.upcase
        when "JUEGO DE EMPAQUES"
          [ attribute(text, VALVES, "Número", "Número de válvulas", nil, :to_i),
            attribute(text, DIAMETER, "Diámetro", "Diámetro", "mm", :to_f),
            attribute(text, GASKET_MATERIAL, "Material", "Junta Cabeza", nil, :upcase) ].compact
        when "KIT BANDA POLEA Y B. AGUA"
          [ attribute(text, TEETH, "Dientes", "Dientes", "dientes", :to_i) ].compact
        else
          []
        end
      end

      private

      def attribute(text, pattern, group, name, unit, conversion)
        matches = text.to_enum(:scan, pattern).map { Regexp.last_match }
        values = matches.map { |match| match[1].public_send(conversion) }.uniq
        return unless values.one?

        raw = pattern == GASKET_MATERIAL ? matches.first[1] : matches.first[0]
        { type: "source_product_attribute", raw_value: raw, confidence: "supplier_asserted",
          value: { "class" => group, "name" => name, "unit" => unit, "value" => values.first } }
      end
    end
  end
end
