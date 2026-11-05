require "spec_helper"
require_relative "../../../../app/services/automotive/parsers/reference_parser"

RSpec.describe Automotive::Parsers::ReferenceParser do
  it "extracts leading reference-like tokens without asserting interchange" do
    facts = described_class.new.call("QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL KA24E")

    expect(facts.map { |fact| fact[:value] }).to eq([ "QJC20G", "FS-001225", "JC20" ])
    expect(facts).to all(include(type: "reference_candidate", confidence: "candidate"))
  end

  it "handles numeric-hyphen and suffixed references and stops at product context" do
    facts = described_class.new.call("83-301 SA-76260+20 CHEVROLET V6 4.3")
    expect(facts.map { |fact| fact[:value] }).to eq([ "83-301", "SA-76260+20" ])
  end

  it "does not treat engine codes, years or free text as part references" do
    expect(described_class.new.call("KA24DE NISSAN 76/14")).to be_empty
    expect(described_class.new.call("NISSAN PICKUP L4")).to be_empty
    expect(described_class.new.call("89/03 NISSAN")).to be_empty
  end

  it "handles punctuation and case in leading references" do
    facts = described_class.new.call("hl7011,  fs-001225; Chevrolet V8")
    expect(facts.map { |fact| fact[:value] }).to eq([ "HL7011", "FS-001225" ])
    expect(facts.first[:raw_value]).to eq("hl7011")
  end
end
