module Automotive
  module Knowledge
    module NormalizeVehicleText
      def self.call(value)
        value.to_s.unicode_normalize(:nfkc).strip.downcase.gsub(/\s+/, " ")
      end
    end
  end
end
