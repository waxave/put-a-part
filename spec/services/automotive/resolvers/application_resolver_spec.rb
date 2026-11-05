require "rails_helper"

RSpec.describe Automotive::Resolvers::ApplicationResolver do
  let(:entry) do
    { "identity_version" => "exact-variant-v1", "sku" => "2C4516+STD", "brand" => "HASTING",
      "source_sheet" => "Original", "source_row" => 2, "manufacturer" => "Nissan", "model" => "Altima", "year" => 2003 }
  end

  it "resolves new release entries by exact brand and variant regardless of workbook location" do
    resolver = described_class.new(entries: [ entry ])
    expect(resolver.call(sku: " 2c4516+std ", brand: " hasting ", source_sheet: "Different", source_row: 99)).to eq([ entry ])
    expect(resolver.call(sku: "2C4516+20", brand: "HASTING", source_sheet: "Original", source_row: 2)).to be_empty
    expect(resolver.call(sku: "2C4516", brand: "HASTING", source_sheet: "Original", source_row: 2)).to be_empty
    expect(resolver.call(sku: "2C4516+STD", brand: "OTHER", source_sheet: "Original", source_row: 2)).to be_empty
    expect(resolver.call(sku: "", brand: "", source_sheet: "Original", source_row: 2)).to be_empty
  end

  it "preserves legacy row-specific release semantics" do
    legacy = entry.except("identity_version")
    resolver = described_class.new(entries: [ legacy ])
    expect(resolver.call(sku: "2C4516+STD", brand: "HASTING", source_sheet: "Original", source_row: 2)).to eq([ legacy ])
    expect(resolver.call(sku: "2C4516+STD", brand: "HASTING", source_sheet: "Other", source_row: 2)).to be_empty
    expect(resolver.call(sku: "2c4516+std", brand: "HASTING", source_sheet: "Original", source_row: 2)).to be_empty
  end

  it "refuses unknown identity versions rather than silently changing their meaning" do
    expect { described_class.new(entries: [ entry.merge("identity_version" => "future") ]) }.to raise_error(described_class::UnknownIdentityVersion)
  end
end
