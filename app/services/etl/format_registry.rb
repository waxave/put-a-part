module Etl
  class FormatRegistry
    class UnknownFormat < StandardError; end
    class AmbiguousFormat < StandardError; end

    PROFILES = [ Etl::Formats::SampleSupplier::Profile, Etl::Formats::ColumnMapped::Profile ].freeze

    def self.registered?(key)
      PROFILES.any? { |profile| profile::KEY == key }
    end

    def resolve(workbook, key: nil)
      candidates = key.present? ? PROFILES.select { |profile| profile::KEY == key } : PROFILES.select { |profile| profile.detect?(workbook) }
      raise UnknownFormat, "No supplier profile matches this workbook" if candidates.empty?
      raise AmbiguousFormat, "Multiple supplier profiles match this workbook" if candidates.size > 1

      profile = candidates.first
      raise UnknownFormat, "Selected supplier profile does not match this workbook" unless profile.detect?(workbook)

      profile.new
    end
  end
end
