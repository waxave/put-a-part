require "rails_helper"

RSpec.describe "Database seeds" do
  it "can be loaded repeatedly without duplicating or changing the versioned attribute catalog" do
    initial_catalog = AttributeDefinition.order(:catalog_key).pluck(:catalog_key, :attribute_class, :name, :default_unit, :source_version)

    Rails.application.load_seed
    Rails.application.load_seed

    expect(AttributeDefinition.order(:catalog_key).pluck(:catalog_key, :attribute_class, :name, :default_unit, :source_version)).to eq(initial_catalog)
    expect(AttributeDefinition.count).to eq(13)
  end
end
