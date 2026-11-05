require "digest"
require "json"

module Automotive
  module Knowledge
    class ImportVehicleCatalogSource
      class InvalidRecord < StandardError; end

      SOURCES = {
        "gor3a" => VehicleReferenceSources::Gor3a,
        "vehiclesdb" => VehicleReferenceSources::Vehiclesdb
      }.freeze

      def initialize(source:, path:, apply: false, batch_size: 500)
        @source_name = source.to_s
        @source_class = SOURCES.fetch(@source_name) { raise ArgumentError, "Unsupported source: #{@source_name}" }
        @path = path
        @apply = apply
        @batch_size = Integer(batch_size)
        raise ArgumentError, "Batch size must be positive" unless @batch_size.positive?
      end

      def call
        @make_cache = {}
        @model_cache = {}
        @generation_cache = {}
        @engine_cache = {}
        source = @source_class.new(path: @path)
        attribution = source.attribution
        dataset = dataset_for(source, attribution: attribution) if @apply
        import = import_for(dataset, source) if @apply
        counts = Hash.new(0)
        source.each_record.each_slice(@batch_size) do |batch|
          ActiveRecord::Base.transaction do
            source_records = []
            batch.each do |record|
              issues = validate_record!(record)
              source_records << persist_record(record, source, dataset, import, issues) if @apply
              counts[record.fetch(:type)] += 1
              counts[:total] += 1
              counts[:with_issues] += 1 if issues.any?
            end
            upsert_source_records(source_records) if @apply
          end if @apply
          batch.each do |record|
            issues = validate_record!(record)
            counts[record.fetch(:type)] += 1
            counts[:total] += 1
            counts[:with_issues] += 1 if issues.any?
          end unless @apply
          import.update!(counts: counts.to_h) if @apply
        end

        import&.update!(status: "completed", finished_at: Time.current, counts: counts.to_h)
        { source: @source_name, version: source.source_version, checksum: source.sha256, applied: @apply,
          counts: counts.to_h }
      rescue StandardError => error
        import&.update(status: "failed", finished_at: Time.current, error_summary: error.message.truncate(2_000))
        raise
      ensure
        source&.close
      end

      private

      def dataset_for(source, attribution:)
        dataset = VehicleReferenceDataset.find_or_initialize_by(source_key: source.source_key,
          source_version: source.source_version, sha256: source.sha256)
        dataset.artifact_name = File.basename(source.path)
        dataset.license_identifier = source.license_identifier
        dataset.attribution = attribution
        dataset.schema_version = source.schema_version
        dataset.save! if dataset.new_record? || dataset.changed?
        dataset
      end

      def import_for(dataset, source)
        dataset.vehicle_reference_imports.create!(status: "running", dry_run: false,
          normalizer_version: source.normalizer_version, started_at: Time.current)
      end

      def validate_record!(record)
        type = record.fetch(:type).to_s
        raise InvalidRecord, "Invalid record type: #{type}" unless %w[make model generation engine availability popularity].include?(type)
        raise InvalidRecord, "Source record ID is empty" if record.fetch(:source_id).to_s.empty?

        normalized = record.fetch(:normalized).stringify_keys
        issues = Array(record[:validation_issues]).dup
        issues << "missing_vehicle_kind" if normalized["kind"].to_s.strip.empty?
        issues << "missing_make_name" if normalized["make_name"].to_s.strip.empty?
        issues << "missing_model_name" if type != "make" && normalized["model_name"].to_s.strip.empty?
        issues << "missing_generation_name" if type == "generation" && normalized["generation_name"].to_s.strip.empty?
        issues << "missing_engine_name" if type == "engine" && normalized["engine_name"].to_s.strip.empty?
        issues
      rescue KeyError => error
        raise InvalidRecord, "Record is missing #{error.key}"
      end

      def persist_record(record, source, dataset, import, issues)
        normalized = record.fetch(:normalized).stringify_keys
        identity_errors = issues.any? { |issue| issue.start_with?("missing_") }
        refs = identity_errors ? {} : resolve_canonical_entities(record.fetch(:type), normalized)
        issues += canonical_conflicts(record.fetch(:type), normalized, refs) unless identity_errors
        raw = record.fetch(:raw).stringify_keys
        {
          vehicle_reference_dataset_id: dataset.id,
          vehicle_reference_import_id: import.id,
          source_record_id: record.fetch(:source_id),
          record_type: record.fetch(:type),
          source_parent_id: normalized["generation_source_id"] || normalized["model_source_id"] || normalized["make_source_id"] ||
            raw["generation_id"] || raw["model_id"] || raw["make_id"],
          resolution_status: if identity_errors
            "rejected"
                             elsif issues.any? { |issue| issue.start_with?("canonical_conflict_") }
            "conflict"
                             else
            issues.empty? ? "matched" : "partial"
                             end,
          normalizer_version: source.normalizer_version,
          content_sha256: Digest::SHA256.hexdigest(JSON.generate(raw)),
          raw_record: raw,
          normalized_record: normalized,
          validation_issues: issues,
          vehicle_make_id: refs[:make]&.id,
          vehicle_model_id: refs[:model]&.id,
          vehicle_generation_id: refs[:generation]&.id,
          vehicle_engine_variant_id: refs[:engine]&.id,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      def upsert_source_records(records)
        return if records.empty?

        VehicleReferenceRecord.upsert_all(records, unique_by: :index_vehicle_reference_records_on_dataset_and_source_id,
          update_only: %i[vehicle_reference_import_id source_parent_id record_type resolution_status normalizer_version
            content_sha256 raw_record normalized_record validation_issues vehicle_make_id vehicle_model_id
            vehicle_generation_id vehicle_engine_variant_id])
      end

      def resolve_canonical_entities(type, normalized)
        make = find_or_create_make(normalized.fetch("make_name"))
        return { make: make } if type == "make"

        model = find_or_create_model(make, normalized.fetch("model_name"), normalized.fetch("kind"))
        return { make: make, model: model } unless %w[generation engine].include?(type)

        generation = find_or_create_generation(model, normalized) if type == "generation" || type == "engine"
        return { make: make, model: model, generation: generation } unless type == "engine"

        engine = find_or_create_engine(generation, normalized)
        { make: make, model: model, generation: generation, engine: engine }
      end

      def find_or_create_make(name)
        normalized_name = NormalizeVehicleText.call(name)
        @make_cache[normalized_name] ||= VehicleMake.find_or_create_by!(normalized_name: normalized_name) do |make|
          make.name = name.to_s.strip
        end
      end

      def find_or_create_model(make, name, kind)
        normalized_name = NormalizeVehicleText.call(name)
        key = [ make.id, kind.to_s, normalized_name ]
        @model_cache[key] ||= VehicleModel.find_or_create_by!(vehicle_make: make, normalized_name: normalized_name, vehicle_kind: kind.to_s) do |model|
          model.name = name.to_s.strip
        end
      end

      def find_or_create_generation(model, normalized)
        name = normalized.fetch("generation_name").to_s.strip
        normalized_name = NormalizeVehicleText.call(name)
        key = [ model.id, normalized_name ]
        @generation_cache[key] ||= VehicleGeneration.find_or_create_by!(vehicle_model: model, normalized_name: normalized_name) do |generation|
          generation.name = name
          generation.year_start = normalized["year_start"]
          generation.year_end = normalized["year_end"]
          generation.body_type = normalized["body_type"]
          generation.source_attributes = normalized.except("kind", "make_name", "model_name", "model_source_id", "generation_name",
            "year_start", "year_end", "body_type")
        end
      end

      def find_or_create_engine(generation, normalized)
        name = normalized.fetch("engine_name").to_s.strip
        normalized_name = NormalizeVehicleText.call(name)
        key = [ generation.id, normalized_name ]
        @engine_cache[key] ||= VehicleEngineVariant.find_or_create_by!(vehicle_generation: generation, normalized_name: normalized_name) do |engine|
          engine.name = name
          engine.fuel_type = normalized["fuel_type"]
          engine.cylinder_count = normalized["cylinder_count"]
          engine.displacement_cc = normalized["displacement_cc"]
          engine.power_hp = normalized["power_hp"]
          engine.torque_nm = normalized["torque_nm"]
          engine.transmission = normalized["transmission"]
          engine.drivetrain = normalized["drivetrain"]
          engine.specifications = { "engine_specs" => normalized.fetch("specifications", []) }.merge(
            normalized.except("kind", "make_name", "model_name", "model_source_id", "generation_source_id",
              "generation_name", "engine_name", "specifications",
              "fuel_type", "cylinder_count", "displacement_cc", "power_hp", "torque_nm", "transmission", "drivetrain"))
        end
      end

      def canonical_conflicts(type, normalized, refs)
        conflicts = []
        if type == "generation"
          generation = refs.fetch(:generation)
          %w[year_start year_end body_type].each do |field|
            incoming = normalized[field]
            existing = generation.public_send(field)
            conflicts << "canonical_conflict_#{field}: #{existing} != #{incoming}" if incoming.present? && existing.present? && existing.to_s != incoming.to_s
          end
        elsif type == "engine"
          engine = refs.fetch(:engine)
          %w[fuel_type cylinder_count displacement_cc power_hp torque_nm transmission drivetrain].each do |field|
            incoming = normalized[field]
            existing = engine.public_send(field)
            conflicts << "canonical_conflict_#{field}: #{existing} != #{incoming}" if incoming.present? && existing.present? && existing.to_s != incoming.to_s
          end
          incoming_specs = Array(normalized["specifications"]).group_by { |item| item["key"] }
          existing_specs = Array(engine.specifications.to_h["engine_specs"]).group_by { |item| item["key"] }
          incoming_specs.each do |key, values|
            existing = existing_specs[key]
            conflicts << "canonical_conflict_specification_#{key}" if existing.present? && existing != values
          end
        end
        conflicts
      end
    end
  end
end
