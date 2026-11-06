module Automotive
  module Knowledge
    class RebuildVehicleSearchIndex
      def self.call(batch_size: 1_000)
        new(batch_size: batch_size).call
      end

      def initialize(batch_size: 1_000)
        @batch_size = Integer(batch_size)
        raise ArgumentError, "Batch size must be positive" unless @batch_size.positive?
      end

      def call
        now = Time.current
        entries = []
        model_terms = VehicleReferenceRecord.where(record_type: "model").where.not(vehicle_model_id: nil)
          .pluck(:vehicle_model_id, :normalized_record).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(model_id, normalized), terms|
            %w[body_types regions slug year_start year_end source_group].each do |field|
              value = normalized[field]
              values = value.is_a?(Array) ? value : [ value ]
              terms[model_id].concat(values.filter_map { |item| item.to_s if item.is_a?(String) || item.is_a?(Numeric) })
            end
          end

        VehicleSearchEntry.transaction do
          VehicleSearchEntry.delete_all

          VehicleMake.find_each do |make|
            entries << entry({ vehicle_make_id: make.id }, entry_type: "make", text: make.name, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          VehicleModel.includes(:vehicle_make).find_each do |model|
            text = [ model.vehicle_make.name, model.vehicle_kind, model.name, *model_terms[model.id] ].compact.join(" ")
            entries << entry({ vehicle_model_id: model.id }, entry_type: "model", text: text, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          VehicleConfiguration.includes(vehicle_model: :vehicle_make).find_each do |configuration|
            model = configuration.vehicle_model
            attributes = configuration.configuration.to_h.values.filter_map do |value|
              value.to_s if value.is_a?(String) || value.is_a?(Numeric)
            end
            text = [ model.vehicle_make.name, model.name, configuration.model_year, configuration.submodel,
              configuration.engine_code, configuration.displacement_liters, configuration.cylinder_count, *attributes ].compact.join(" ")
            entries << entry({ vehicle_configuration_id: configuration.id }, entry_type: "configuration", text: text, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          VehicleGeneration.includes(vehicle_model: :vehicle_make).find_each do |generation|
            model = generation.vehicle_model
            text = [ model.vehicle_make.name, model.vehicle_kind, model.name, generation.name,
              generation.year_start, generation.year_end, generation.body_type ].compact.join(" ")
            entries << entry({ vehicle_generation_id: generation.id }, entry_type: "generation", text: text, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          VehicleEngineVariant.includes(vehicle_generation: { vehicle_model: :vehicle_make }).find_each do |engine|
            generation = engine.vehicle_generation
            model = generation.vehicle_model
            source_specs = Array(engine.specifications.to_h["engine_specs"]).flat_map { |spec| [ spec["key"], spec["value"] ] }
            attributes = (engine.specifications.to_h.except("engine_specs").values.flatten + source_specs).filter_map do |value|
              value.to_s if value.is_a?(String) || value.is_a?(Numeric)
            end
            text = [ model.vehicle_make.name, model.vehicle_kind, model.name, generation.name, engine.name,
              engine.fuel_type, engine.cylinder_count, engine.displacement_cc, engine.power_hp,
              engine.torque_nm, engine.transmission, engine.drivetrain, *attributes ].compact.join(" ")
            entries << entry({ vehicle_engine_variant_id: engine.id }, entry_type: "engine", text: text, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          VehicleAlias.where(review_status: "accepted").includes(:vehicle_make, :vehicle_model, :vehicle_configuration).find_each do |vehicle_alias|
            entity = vehicle_alias.vehicle_make || vehicle_alias.vehicle_model || vehicle_alias.vehicle_configuration
            text = [ vehicle_alias.alias_text, vehicle_alias.vehicle_model&.vehicle_make&.name,
              vehicle_alias.vehicle_model&.name, vehicle_alias.vehicle_configuration&.vehicle_model&.name ].compact.join(" ")
            reference = case entity
            when VehicleMake then { vehicle_make_id: entity.id }
            when VehicleModel then { vehicle_model_id: entity.id }
            else { vehicle_configuration_id: entity.id }
            end
            entries << entry(reference, entry_type: "alias", text: text, now: now)
            flush(entries) if entries.size >= @batch_size
          end

          flush(entries)
        end

        VehicleSearchEntry.count
      end

      private

      def entry(entity_reference, entry_type:, text:, now:)
        display = text.to_s.squish
        { vehicle_make_id: nil, vehicle_model_id: nil, vehicle_configuration_id: nil, vehicle_generation_id: nil,
          vehicle_engine_variant_id: nil }.merge(entity_reference).merge(
          entry_type: entry_type, display_text: display,
          normalized_text: display.downcase, created_at: now, updated_at: now)
      end

      def flush(entries)
        return if entries.empty?

        VehicleSearchEntry.insert_all!(entries)
        entries.clear
      end
    end
  end
end
