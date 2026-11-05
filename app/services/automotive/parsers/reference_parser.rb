require_relative "description_parser"

module Automotive
  module Parsers
    # Reference-shaped tokens are candidates only, never verified interchanges.
    class ReferenceParser < Automotive::ServiceBase
      TOKEN = /\A(?=.*\d)(?=.*[A-Z+\-])[A-Z0-9]+(?:[-+][A-Z0-9]+)*\z/i

      def call(description)
        description.to_s.split.each_with_object([]) do |raw_token, facts|
          token = raw_token.sub(/[,;]+\z/, "")
          break facts if !TOKEN.match?(token) || DescriptionParser::ENGINE.match?(token) || token.match?(/\A[LV]\d{1,2}\z/i)

          facts << { type: "reference_candidate", value: token.upcase, raw_value: token, confidence: "candidate" }
        end
      end
    end
  end
end
