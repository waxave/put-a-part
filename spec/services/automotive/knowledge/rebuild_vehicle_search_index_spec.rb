require "rails_helper"

RSpec.describe Automotive::Knowledge::RebuildVehicleSearchIndex do
  it "indexes existing makes, models and configurations with evidenced attributes" do
    make = VehicleMake.create!(name: "Fixture Motors", normalized_name: "fixture motors")
    model = VehicleModel.create!(vehicle_make: make, name: "Trail Runner", normalized_name: "trail runner")
    VehicleConfiguration.create!(vehicle_model: model, model_year: 2024, engine_code: "X2", configuration: { "body" => "wagon" })
    VehicleAlias.create!(vehicle_model: model, alias_text: "Offroad Wagon", normalized_alias: "offroad wagon",
      source_key: "fixture", review_status: "accepted")
    VehicleAlias.create!(vehicle_model: model, alias_text: "Unreviewed Name", normalized_alias: "unreviewed name",
      source_key: "fixture")

    expect(described_class.new(batch_size: 2).call).to eq(4)
    expect(VehicleSearchEntry.full_text("2024 wagon").pluck(:entry_type)).to eq([ "configuration" ])
    expect(VehicleSearchEntry.full_text("Fixture Runner").pluck(:entry_type)).to include("model")
    expect(VehicleSearchEntry.full_text("Offroad").pluck(:entry_type)).to include("alias")
    expect(VehicleSearchEntry.full_text("Unreviewed")).to be_empty
  end

  it "requires a positive batch size" do
    expect { described_class.new(batch_size: 0) }.to raise_error(ArgumentError)
  end
end
