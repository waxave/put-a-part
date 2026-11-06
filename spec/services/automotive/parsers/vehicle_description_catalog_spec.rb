require "rails_helper"

RSpec.describe Automotive::Parsers::VehicleDescriptionParser do
  it "splits a description into separate models known to the local vehicle catalog" do
    make = VehicleMake.create!(name: "Dodge")
    VehicleModel.create!(vehicle_make: make, name: "Durango", vehicle_kind: "car")
    VehicleModel.create!(vehicle_make: make, name: "Journey", vehicle_kind: "car")
    VehicleModel.create!(vehicle_make: make, name: "Grand Cherokee", vehicle_kind: "car")

    vehicles = Automotive::Parsers::DescriptionParser.call("CHRYSLER DURANGO JOURNEY GRAND CHEROKEE 2011-2013")
      .select { |fact| fact[:type] == "vehicle_candidate" }

    expect(vehicles.map { |fact| fact.dig(:value, "model") }).to eq([ "DURANGO", "JOURNEY", "GRAND CHEROKEE" ])
    expect(vehicles.map { |fact| fact.dig(:value, "make") }).to eq([ "Dodge", "Dodge", "Dodge" ])
    expect(vehicles.map { |fact| fact.dig(:value, "source_make") }).to eq([ "Chrysler", "Chrysler", "Chrysler" ])
    expect(vehicles.map { |fact| fact.dig(:value, "make_match_status") }).to all(eq("catalog_make_mismatch"))
    expect(vehicles.map { |fact| [ fact.dig(:value, "year_start"), fact.dig(:value, "year_end") ] })
      .to eq([ [ 2011, 2013 ], [ 2011, 2013 ], [ 2011, 2013 ] ])
  end

  it "does not treat a short engine marker as a cross-make model match" do
    make = VehicleMake.create!(name: "Li Auto")
    VehicleModel.create!(vehicle_make: make, name: "L6", vehicle_kind: "car")

    vehicles = Automotive::Parsers::DescriptionParser.call("NISSAN PICKUP L4 L6 1.8 2.4 KA24DE 76/14")
      .select { |fact| fact[:type] == "vehicle_candidate" }

    expect(vehicles.map { |fact| fact.dig(:value, "make") }).not_to include("Li Auto")
    expect(vehicles.map { |fact| fact.dig(:value, "source_make") }).not_to include("Nissan")
  end
end
