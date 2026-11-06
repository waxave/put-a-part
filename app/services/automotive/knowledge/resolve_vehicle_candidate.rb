module Automotive
  module Knowledge
    class ResolveVehicleCandidate
      include ServiceCall

      def call(candidate, external_system:, source_version:)
        candidate.vehicle_candidate_matches.where(external_system: external_system, source_version: source_version).delete_all
        return candidate.update!(resolution_status: "unresolved") if candidate.make_candidate.blank? || candidate.model_candidate.blank? || !candidate.model_year_start || !candidate.model_year_end

        make = VehicleMake.find_by(normalized_name: normalize(candidate.make_candidate))
        model = VehicleModel.find_by(vehicle_make: make, normalized_name: normalize(candidate.model_candidate)) if make
        configurations = if model
          model.vehicle_configurations.where(model_year: candidate.model_year_start..candidate.model_year_end)
        else
          VehicleConfiguration.none
        end
        if candidate.engine_code_candidate.present?
          configurations = configurations.where("LOWER(engine_code) = ?", candidate.engine_code_candidate.downcase)
        end
        matches = configurations.order(:model_year, :id).to_a
        matches.each do |configuration|
          candidate.vehicle_candidate_matches.create!(vehicle_configuration: configuration, external_system: external_system,
            source_version: source_version, match_reason: "exact_make_model_year_engine")
        end

        years = matches.map(&:model_year).uniq
        expected_years = (candidate.model_year_start..candidate.model_year_end).to_a
        status = if matches.empty?
          "no_match"
        elsif matches.group_by(&:model_year).any? { |_year, configs| configs.length > 1 }
          "ambiguous"
        elsif years == expected_years
          "matched"
        else
          "partial"
        end
        candidate.update!(resolution_status: status)
      end

      private

      def normalize(value)
        value.to_s.strip.downcase.gsub(/\s+/, " ")
      end
    end
  end
end
