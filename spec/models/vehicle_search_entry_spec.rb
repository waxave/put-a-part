require "rails_helper"

RSpec.describe VehicleSearchEntry do
  it "finds normalized catalog terms through PostgreSQL full-text search" do
    make = VehicleMake.create!(name: "Search Fixture Motors", normalized_name: "search fixture motors")
    described_class.create!(vehicle_make: make, entry_type: "make", display_text: "Search Fixture Motors",
      normalized_text: "search fixture motors")

    expect(described_class.full_text("Fixture Motors").pluck(:vehicle_make_id)).to include(make.id)
  end

  it "requires exactly one canonical entity" do
    entry = described_class.new(entry_type: "make", display_text: "Example", normalized_text: "example")

    expect(entry).not_to be_valid
  end
end
