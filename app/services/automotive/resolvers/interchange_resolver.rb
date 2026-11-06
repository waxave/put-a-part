module Automotive
  module Resolvers
    class InterchangeResolver
      def self.call(entries:, sku:, brand:)
        new(entries: entries).call(sku: sku, brand: brand)
      end

      def initialize(entries:)
        @entries = entries.select { |entry| entry["entry_type"] == "interchange" }
        unless @entries.all? { |entry| entry["identity_version"] == ApplicationResolver::IDENTITY_VERSION }
          raise ApplicationResolver::UnknownIdentityVersion, "Unsupported interchange identity version"
        end
      end

      def call(sku:, brand:)
        return [] if sku.to_s.strip.empty? || brand.to_s.strip.empty?

        @entries.select { |entry| entry["sku"].to_s.strip.casecmp?(sku.to_s.strip) && entry["brand"].to_s.strip.casecmp?(brand.to_s.strip) }
          .uniq { |entry| [ entry["interchange_reference"].to_s.strip.upcase, entry["interchange_brand"].to_s.strip.upcase ] }
      end
    end
  end
end
