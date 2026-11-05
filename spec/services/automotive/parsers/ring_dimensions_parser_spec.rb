require "spec_helper"
require_relative "../../../../app/services/automotive/parsers/ring_dimensions_parser"

RSpec.describe Automotive::Parsers::RingDimensionsParser do
  it "extracts diameter and three ring widths without inventing other facts" do
    result = described_class.new.call("QR25DE 89X1.2X1.2X2")

    expect(result).to eq(diameter_mm: 89.0, ring_widths_mm: [ 1.2, 1.2, 2.0 ], raw: "89X1.2X1.2X2")
  end

  it "returns no dimensions for incomplete or unrelated text" do
    expect(described_class.new.call("QR25DE 89X1.2")).to be_nil
    expect(described_class.new.call("no dimensions")).to be_nil
  end
end
