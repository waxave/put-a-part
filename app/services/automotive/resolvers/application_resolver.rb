module Automotive
  module Resolvers
    # Existing unversioned releases retain their original row-specific semantics.
    class ApplicationResolver
      def self.call(entries:, sku:, brand:, source_sheet:, source_row:)
        new(entries: entries).call(sku: sku, brand: brand, source_sheet: source_sheet, source_row: source_row)
      end

      class UnknownIdentityVersion < StandardError; end
      IDENTITY_VERSION = "exact-variant-v1"

      def initialize(entries:)
        @index = Hash.new { |hash, key| hash[key] = [] }
        entries.each_with_index do |entry, position|
          next if entry["entry_type"].in?(%w[attribute catalog_field interchange])

          version = entry["identity_version"]
          key = case version
          when nil
            [ :legacy, entry["source_sheet"], entry["source_row"], entry["sku"], entry["brand"] ]
          when IDENTITY_VERSION
            identity_key(entry["sku"], entry["brand"])
          else
            raise UnknownIdentityVersion, "Unsupported application identity version"
          end
          @index[key] << [ position, entry ] if key
        end
      end

      def call(sku:, brand:, source_sheet:, source_row:)
        legacy_key = [ :legacy, source_sheet, source_row, sku, brand ]
        key = identity_key(sku, brand)
        matches = @index.fetch(legacy_key, []) + (key ? @index.fetch(key, []) : [])
        matches.sort_by(&:first).map(&:last)
      end

      private

      def identity_key(sku, brand)
        return unless sku.is_a?(String) && brand.is_a?(String)

        sku, brand = sku.strip.upcase, brand.strip.upcase
        return if sku.empty? || brand.empty?

        [ :variant, sku, brand ]
      end
    end
  end
end
