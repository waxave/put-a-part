require_relative "../service_base"
require_relative "year_range_parser"
require_relative "vehicle_description_parser"

module Automotive
  module Parsers
    # Recognition only: candidates are not linked to a part or a vehicle.
    class DescriptionParser < Automotive::ServiceBase
      ENGINE = /\b(?:KA\d{2}[A-Z]{1,3}|QR\d{2}[A-Z]{1,3}|L\d{2}[A-Z]\d?|LS[1-9])\b/i
      ENGINE_FAMILY = /\bVORTEC\b/i
      CYLINDERS = /\b(?:[LV]([1-9]\d?)|([1-9]\d?)\s*CIL(?:INDROS?)?)\b/i
      VALVES = /\b(\d{1,2})\s*(?:VAL(?:VULAS?)?|V)\b/i
      CAMSHAFT = /\b(?:DOHC|SOHC)\b/i
      DISPLACEMENT = /(?<![\w.])([1-9]\.\d{1,2})(?:\s*(?:LITROS?|L))?(?![\w.])/i
      DIMENSION_SECTION = /\b(?:RAN(?:URAS?)?|DIENTES|PERNO)\b/i

      def call(description, year_cutoff: YearRangeParser::CUTOFF)
        text = description.to_s
        found = []
        scan(text, ENGINE, "engine_code_candidate", found) { |match| match[0].upcase }
        scan(text, ENGINE_FAMILY, "engine_family_candidate", found) { |match| match[0].upcase }
        scan(text, CYLINDERS, "cylinder_count_candidate", found) { |match| (match[1] || match[2]).to_i }
        if CYLINDERS.match?(text)
          engine_text = text.split(DIMENSION_SECTION, 2).first
          scan(engine_text, DISPLACEMENT, "displacement_liters_candidate", found) { |match| match[1].to_f }
        end
        scan(text, VALVES, "valve_count_candidate", found) { |match| match[1].to_i }
        scan(text, CAMSHAFT, "camshaft_candidate", found) { |match| match[0].upcase }
        year_ranges = []
        text.to_enum(:scan, YearRangeParser::PATTERN).each do
          match = Regexp.last_match
          fact = YearRangeParser.call(match[1], match[3], raw_value: match[0], cutoff: year_cutoff)
          fact[:position] = match.begin(0)
          year_ranges << fact
          found << [ match.begin(0), fact.except(:position) ]
        end
        VehicleDescriptionParser.call(text, year_ranges: year_ranges).each do |fact|
          position = text.index(fact[:raw_value]) || 0
          found << [ position, fact ]
        end
        found.sort_by!(&:first)
        found.map(&:last).uniq { |fact| [ fact[:type], fact[:value] ] }
      end

      private

      def scan(text, pattern, type, found)
        text.to_enum(:scan, pattern).each do
          match = Regexp.last_match
          found << [ match.begin(0), { type: type, value: yield(match), raw_value: match[0], confidence: "candidate" } ]
        end
      end
    end
  end
end
