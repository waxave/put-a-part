module Automotive
  module Parsers
    # Conservative lexical extraction: these are description candidates, not fitments.
    class VehicleDescriptionParser < Automotive::ServiceBase
      MAKES = %w[
        ACURA AUDI BMW BUICK CADILLAC CHEVROLET CHEVY CHRYSLER DAEWOO DAIHATSU DATSUN DODGE FIAT FORD GEO GMC HONDA
        HUMMER HYUNDAI INFINITI ISUZU JAGUAR JEEP KIA LEXUS LINCOLN MAZDA MERCEDES-BENZ MERCEDES MERCURY MINI MITSUBISHI NISSAN
        OLDSMOBILE PLYMOUTH PONTIAC PORSCHE RAM RENAULT SAAB SATURN SCION SEAT SUBARU SUZUKI TESLA TOYOTA VOLKSWAGEN
        VOLVO VW
      ].freeze
      MAKE_PATTERN = /\b(?:#{MAKES.sort_by { |make| -make.length }.join("|")})\b/i
      MODEL_STOP = /\A(?:\d+(?:\.\d+)?|\d{2,4}cc|\d+\s*cil(?:indros?)?|cil(?:indros?)?|valvulas?|valv|do?hc|sohc|dohc|v[0-9]{1,2}|(?:KA|QR)\d{2}[A-Z0-9]*|L\d{2}[A-Z]\d?|VORTEC|LS[0-9]+)\z/i

      def call(description, year_ranges: [])
        text = description.to_s
        makes = text.to_enum(:scan, MAKE_PATTERN).map { Regexp.last_match.dup }
        makes.each_with_index.map do |match, index|
          boundary = makes[index + 1]&.begin(0) || text.length
          range = range_for(match, boundary, year_ranges, allow_preceding: index.zero?)
          make = normalize_make(match[0])
          segment = model_segment(text, match.end(0), range, boundary)
          models = catalog_vehicle_matches(make, segment)
          if models.empty?
            candidate_model = model_candidate(text, match.end(0), range, boundary)
            models = candidate_model.present? ? [ { make: make, model: candidate_model } ] : []
          end
          raw_value = text[match.begin(0)...(range && range[:position] >= match.end(0) ? range[:position] + range[:raw_value].length : boundary)].to_s.strip
          models.compact.map do |vehicle|
            value = { "make" => vehicle[:make], "model" => vehicle[:model],
              "year_start" => range&.fetch(:start_year, nil), "year_end" => range&.fetch(:end_year, nil),
              "year_range_status" => range&.fetch(:interpretation_status, nil) }
            if vehicle[:make] != make
              value["source_make"] = make
              value["make_match_status"] = vehicle[:make_match_status] || "catalog_make_mismatch"
            end
            { type: "vehicle_candidate", value: value.compact,
              raw_value: raw_value, confidence: "candidate" }
          end
        end.flatten.uniq { |candidate| candidate[:value] }
      end

      private

      def normalize_make(make)
        return "Chevrolet" if make.casecmp?("CHEVY")
        return "Volkswagen" if make.casecmp?("VW")
        return "Mercedes-Benz" if make.casecmp?("MERCEDES-BENZ")

        make.split.map(&:capitalize).join(" ")
      end

      def range_for(match, boundary, ranges, allow_preceding:)
        ranges = Array(ranges)
        ranges.find { |range| range[:position] >= match.end(0) && range[:position] < boundary } ||
          (ranges.select { |range| range[:position] < match.begin(0) }.max_by { |range| range[:position] } if allow_preceding)
      end

      def model_candidate(text, start_at, range, boundary)
        segment = model_segment(text, start_at, range, boundary)
        words = segment.scan(/[A-Za-z0-9][A-Za-z0-9-]*/).take_while { |word| !MODEL_STOP.match?(word) }
        candidate = words.first(3).join(" ")
        candidate unless candidate.empty?
      end

      def model_segment(text, start_at, range, boundary)
        finish = [ boundary, range && range[:position] > start_at ? range[:position] : boundary ].min
        text[start_at...finish].to_s
      end

      def catalog_vehicle_matches(make_name, segment)
        return [] unless defined?(VehicleMake) && VehicleMake.table_exists?

        make_record = VehicleMake.find_by(normalized_name: normalize(make_name))
        searchable = normalize(segment.split(/[[:space:]]+/).take_while { |word| !MODEL_STOP.match?(word) }.join(" "))
        return [] if searchable.empty?

        hits = matching_catalog_models(searchable)
        exact_make_hits = hits.select { |hit| hit[:make_id] == make_record&.id }
        selected = non_overlapping(exact_make_hits)
        return selected.map { |hit| { make: hit[:make_name], model: hit[:name].upcase } } if selected.any?

        hits.reject! { |hit| hit[:normalized_name].match?(/\A[a-z]\d\z/) }
        return [] if hits.empty?

        selected = non_overlapping(hits)
        make_scores = selected.group_by { |hit| hit[:make_id] }.transform_values { |models| models.map { |hit| hit[:normalized_name] }.uniq.length }
        top_score = make_scores.values.max
        leading_makes = make_scores.select { |_id, score| score == top_score }.keys
        if leading_makes.one?
          selected.select { |hit| hit[:make_id] == leading_makes.first }
            .map { |hit| { make: hit[:make_name], model: hit[:name].upcase } }
        else
          selected.map do |hit|
            { make: make_name, model: hit[:name].upcase, make_match_status: "ambiguous_catalog_make" }
          end.uniq { |hit| hit[:model] }
        end
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        []
      end

      def matching_catalog_models(searchable)
        VehicleModel.joins(:vehicle_make).where(normalized_name: phrase_terms(searchable))
          .pluck(:id, :name, :normalized_name, :vehicle_make_id, "vehicle_makes.name")
          .filter_map do |_id, name, normalized_name, make_id, make_name|
            normalized_name = normalize(normalized_name)
            next if normalized_name.empty?

            match = /(?<![[:alnum:]])#{Regexp.escape(normalized_name)}(?![[:alnum:]])/.match(searchable)
            { start: match.begin(0), finish: match.end(0), name: name, normalized_name: normalized_name,
              make_id: make_id, make_name: make_name } if match
          end
      end

      def non_overlapping(hits)
        selected = []
        hits.sort_by { |hit| [ hit[:start], -(hit[:finish] - hit[:start]) ] }.each do |hit|
          selected << hit unless selected.any? { |existing| hit[:start] < existing[:finish] && existing[:start] < hit[:finish] }
        end
        selected.sort_by { |hit| hit[:start] }
      end

      def normalize(value)
        value.to_s.unicode_normalize(:nfkc).strip.downcase.gsub(/\s+/, " ")
      end

      def phrase_terms(value)
        words = value.split
        (1..[ words.length, 6 ].min).flat_map do |length|
          (0..words.length - length).map { |start| words[start, length].join(" ") }
        end.uniq
      end
    end
  end
end
