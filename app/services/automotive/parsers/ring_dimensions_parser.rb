module Automotive
  module Parsers
    class RingDimensionsParser < Automotive::ServiceBase
      PATTERN = /(?<![\d.])(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+(?:\.\d+)?)\s*[xX×]\s*(\d+(?:\.\d+)?)(?![\d.])/i

      def call(description)
        match = PATTERN.match(description.to_s)
        return unless match

        { diameter_mm: match[1].to_f, ring_widths_mm: match.captures.drop(1).map(&:to_f), raw: match[0] }
      end
    end
  end
end
