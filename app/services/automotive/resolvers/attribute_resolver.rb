module Automotive
  module Resolvers
    class AttributeResolver
      def self.call(entries:, sku:, brand:, facts: [])
        new(entries: entries).call(sku: sku, brand: brand, facts: facts)
      end

      def initialize(entries:)
        @entries = entries.select { |entry| entry["entry_type"] == "attribute" }
        unless @entries.all? { |entry| entry["identity_version"] == ApplicationResolver::IDENTITY_VERSION }
          raise ApplicationResolver::UnknownIdentityVersion, "Unsupported attribute identity version"
        end
      end

      def call(sku:, brand:, facts: [])
        return { attributes: [], conflicts: [] } if sku.to_s.strip.empty? || brand.to_s.strip.empty?

        matches = @entries.select do |entry|
          entry["sku"].to_s.strip.casecmp?(sku.to_s.strip) && entry["brand"].to_s.strip.casecmp?(brand.to_s.strip)
        end
        groups = matches.group_by { |entry| [ entry["attribute_class"].to_s.strip.downcase, entry["name"].to_s.strip.downcase ] }
        attributes = []
        conflicts = []
        groups.each do |key, entries|
          variants = entries.map { |entry| [ entry["unit"].to_s.strip.downcase, entry["value"].to_s.strip ] }.uniq
          existing = source_values(facts, key)
          if variants.one? && existing.all? { |value| value == variants.first }
            attributes << entries.first if existing.empty?
          else
            conflicts << entries
          end
        end
        { attributes: attributes, conflicts: conflicts }
      end

      private

      def source_values(facts, key)
        facts.flat_map do |fact|
          if fact["type"] == "source_product_attribute" && fact["confidence"] == "supplier_asserted"
            value = fact["value"] || {}
            [ [ value["class"], value["name"], value["unit"], value["value"] ] ]
          elsif fact["type"] == "ring_dimensions" && fact["value"].is_a?(Hash)
            value = fact["value"]
            [ [ "Diámetro", "Diámetro", "mm", value["diameter_mm"] ] ] + Array(value["ring_widths_mm"]).each_with_index.map do |width, index|
              ring = "Anillo#{index + 1}"
              [ ring, "#{ring} Espesor", "mm", width ]
            end
          else
            []
          end
        end.filter_map do |klass, name, unit, value|
          next unless [ klass.to_s.strip.downcase, name.to_s.strip.downcase ] == key

          [ unit.to_s.strip.downcase, value.to_s.strip ]
        end
      end
    end
  end
end
