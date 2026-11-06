module Automotive
  module Domain
    module VehicleKindLabels
      LABELS = {
        "car" => "Automóvil",
        "truck" => "Camión",
        "motorcycle" => "Motocicleta",
        "bus" => "Autobús",
        "van" => "Furgoneta",
        "suv" => "SUV",
        "atv" => "Cuatrimoto",
        "boat" => "Embarcación"
      }.freeze

      def self.call(kind)
        LABELS[kind.to_s.strip.downcase]
      end
    end
  end
end
