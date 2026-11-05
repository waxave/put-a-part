module Automotive
  module Parsers
    class YearRangeParser < Automotive::ServiceBase
      CUTOFF = 30
      PATTERN = /(?<![A-Za-z0-9])((?:\d{2}|\d{4}))\s*([\/\-–—])\s*((?:\d{2}|\d{4}))(?![A-Za-z0-9])/i
      MIN_YEAR = 1886
      MAX_YEAR = 2100
      MAX_RANGE_SPAN = 75

      def call(start_token, end_token, raw_value: nil, cutoff: CUTOFF)
        start_year = expand(start_token, cutoff)
        end_year = expand(end_token, cutoff)
        end_year += 100 if start_token.to_s.length == 2 && end_token.to_s.length == 2 && start_year == 1900 + start_token.to_i && end_year < start_year && end_token.to_i <= cutoff

        reason = if start_year < MIN_YEAR || end_year > MAX_YEAR
          "outside_supported_year_bounds"
        elsif end_year < start_year
          "descending_year_range"
        elsif end_year - start_year > MAX_RANGE_SPAN
          "implausibly_wide_year_range"
        end

        { type: "year_range_candidate", value: raw_value || "#{start_token}/#{end_token}", raw_value: raw_value || "#{start_token}/#{end_token}",
          start_year: start_year, end_year: end_year, century_policy: "two_centuries_cutoff_#{cutoff}_v1",
          interpretation_status: reason ? "unresolved" : "interpreted",
          unresolved_reason: reason, confidence: "candidate" }.compact
      end

      private

      def expand(token, cutoff)
        value = token.to_i
        return value if token.to_s.length == 4

        value <= cutoff ? 2000 + value : 1900 + value
      end
    end
  end
end
