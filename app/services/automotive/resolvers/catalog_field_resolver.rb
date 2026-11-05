module Automotive
  module Resolvers
    class CatalogFieldResolver
      def initialize(entries:)
        @entries = entries.select { |entry| entry["entry_type"] == "catalog_field" }
        unless @entries.all? { |entry| entry["identity_version"] == ApplicationResolver::IDENTITY_VERSION && Automotive::Domain::CatalogFields::NAMES.include?(entry["field"]) }
          raise ApplicationResolver::UnknownIdentityVersion, "Unsupported catalog field or identity version"
        end
      end

      def call(sku:, brand:)
        return { fields: {}, conflicts: [] } if sku.to_s.strip.empty? || brand.to_s.strip.empty?

        matches = @entries.select { |entry| entry["sku"].to_s.strip.casecmp?(sku.to_s.strip) && entry["brand"].to_s.strip.casecmp?(brand.to_s.strip) }
        fields = {}
        conflicts = []
        matches.group_by { |entry| entry["field"] }.each do |field, entries|
          values = entries.map { |entry| entry["value"].to_s.strip }.uniq
          values.one? ? fields[field] = entries.first : conflicts << entries
        end
        { fields: fields, conflicts: conflicts }
      end
    end
  end
end
