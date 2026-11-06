module Automotive
  module Knowledge
    class ImportVehicleReference
      def self.call(records:, external_system:, source_version:, batch_size: 500)
        new(batch_size: batch_size).call(records: records, external_system: external_system, source_version: source_version)
      end

      def initialize(batch_size: 500)
        @batch_size = Integer(batch_size)
        raise ArgumentError, "Batch size must be positive" unless @batch_size.positive?
      end

      def call(records:, external_system:, source_version:)
        raise ArgumentError, "External system and source version are required" if external_system.to_s.strip.empty? || source_version.to_s.strip.empty?

        counts = { makes: 0, models: 0, configurations: 0 }
        records.each_slice(@batch_size) do |batch|
          ActiveRecord::Base.transaction do
            batch.each do |raw|
              row = raw.stringify_keys
              validate_row!(row)
              make = persist_make(row, external_system)
              model = persist_model(row, make, external_system)
              persist_configuration(row, model, external_system, source_version)
              counts[:makes] += 1
              counts[:models] += 1
              counts[:configurations] += 1
            end
          end
        end
        counts
      end

      private

      def validate_row!(row)
        required = %w[make_id make_name model_id model_name configuration_id model_year]
        raise ArgumentError, "Vehicle reference row is missing required identifiers or names" if required.any? { |key| row[key].to_s.strip.empty? }

        year = Integer(row["model_year"], exception: false)
        raise ArgumentError, "Vehicle reference row has an invalid model year" unless year && (1886..2100).cover?(year)
      end

      def persist_make(row, external_system)
        make = VehicleMake.find_by(external_system: external_system, external_id: row.fetch("make_id").to_s)
        return make.tap { |entity| entity.update!(name: row.fetch("make_name")) if entity.name != row.fetch("make_name") } if make

        VehicleMake.create!(name: row.fetch("make_name"), normalized_name: normalize(row.fetch("make_name")),
          external_system: external_system, external_id: row.fetch("make_id").to_s)
      end

      def persist_model(row, make, external_system)
        model = VehicleModel.find_by(external_system: external_system, external_id: row.fetch("model_id").to_s)
        return model.tap { |entity| entity.update!(vehicle_make: make, name: row.fetch("model_name")) if entity.name != row.fetch("model_name") || entity.vehicle_make_id != make.id } if model

        VehicleModel.create!(vehicle_make: make, name: row.fetch("model_name"), normalized_name: normalize(row.fetch("model_name")),
          external_system: external_system, external_id: row.fetch("model_id").to_s)
      end

      def persist_configuration(row, model, external_system, source_version)
        configuration = VehicleConfiguration.find_by(external_system: external_system, external_id: row.fetch("configuration_id").to_s) ||
          VehicleConfiguration.new(external_system: external_system, external_id: row.fetch("configuration_id").to_s)
        configuration.update!(vehicle_model: model, model_year: Integer(row.fetch("model_year")), submodel: row["submodel"],
          engine_code: row["engine_code"], displacement_liters: row["displacement_liters"], cylinder_count: row["cylinder_count"],
          configuration: row["configuration"].is_a?(Hash) ? row["configuration"] : {}, source_version: source_version)
      end

      def normalize(value)
        value.to_s.strip.downcase.gsub(/\s+/, " ")
      end
    end
  end
end
