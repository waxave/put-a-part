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
          model = model_candidate(text, match.end(0), range, boundary)
          next if model.nil? || model.empty?

          { type: "vehicle_candidate", value: { "make" => make, "model" => model,
            "year_start" => range&.fetch(:start_year, nil), "year_end" => range&.fetch(:end_year, nil),
            "year_range_status" => range&.fetch(:interpretation_status, nil) }.compact,
            raw_value: text[match.begin(0)...(range && range[:position] >= match.end(0) ? range[:position] + range[:raw_value].length : boundary)].to_s.strip,
            confidence: "candidate" }
        end.compact.uniq { |candidate| candidate[:value] }
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
        finish = [ boundary, range && range[:position] > start_at ? range[:position] : boundary ].min
        segment = text[start_at...finish].to_s
        words = segment.scan(/[A-Za-z0-9][A-Za-z0-9-]*/).take_while { |word| !MODEL_STOP.match?(word) }
        candidate = words.first(3).join(" ")
        candidate unless candidate.empty?
      end
    end
  end
end
