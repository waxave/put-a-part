require "spec_helper"
require_relative "../../../../app/services/automotive/parsers/product_attribute_parser"

RSpec.describe Automotive::Parsers::ProductAttributeParser do
  it "extracts directly stated gasket attributes with their source text" do
    facts = described_class.call(category: "JUEGO DE EMPAQUES", description: "QR25DE DOHC 16 VAL DIAMETRO CAB MLS 89MM")

    expect(facts).to include(
      a_hash_including(type: "source_product_attribute", raw_value: "16 VAL", confidence: "supplier_asserted",
        value: { "class" => "Número", "name" => "Número de válvulas", "unit" => nil, "value" => 16 }),
      a_hash_including(raw_value: "89MM", value: { "class" => "Diámetro", "name" => "Diámetro", "unit" => "mm", "value" => 89.0 }),
      a_hash_including(raw_value: "MLS", value: { "class" => "Material", "name" => "Junta Cabeza", "unit" => nil, "value" => "MLS" })
    )
  end

  it "extracts a belt tooth count only for the supported belt kit family" do
    facts = described_class.call(category: "KIT BANDA POLEA Y B. AGUA", description: "HONDA V6 197 DIENTES")
    expect(facts).to include(a_hash_including(raw_value: "197 DIENTES",
      value: { "class" => "Dientes", "name" => "Dientes", "unit" => "dientes", "value" => 197 }))
    expect(described_class.call(category: "PISTONES", description: "197 DIENTES")).to be_empty
  end

  it "does not choose among conflicting values" do
    facts = described_class.call(category: "JUEGO DE EMPAQUES", description: "8V 12V 89MM 90MM")
    expect(facts).to be_empty
  end
end
