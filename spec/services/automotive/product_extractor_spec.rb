require "rails_helper"

RSpec.describe Automotive::ProductExtractor do
  it "produces source-located candidates independently of the supplier file reader" do
    input = Automotive::Domain::InputRecord.new(source_identifier: 6536, sku: "FSX-5840301", brand_text: "FRACO",
      category_text: "JUEGO DE EMPAQUES", description: "4 CIL KA24E SOHC 12 VAL 89/03",
      structured_fields: { "source_row" => [ 6536, "FSX-5840301" ] }, metadata: { "sheet" => "Origen", "row" => 2 })

    result = described_class.new.call(input)

    expect(result.fetch(:product)).to include("sku" => "FSX-5840301", "brand" => "FRACO")
    expect(result.fetch(:facts)).to include(a_hash_including("type" => "engine_code_candidate", "value" => "KA24E",
      "source" => { "sheet" => "Origen", "row" => 2 }, "confidence" => "candidate"))
    attribute = result.fetch(:facts).find { |fact| fact["type"] == "source_product_attribute" }
    expect(attribute).to include("raw_value" => "12 VAL", "confidence" => "supplier_asserted")
    expect(attribute.fetch("value")).to include("name" => "Número de válvulas", "value" => 12)
  end

  it "keeps alternate reference candidates separate from verified interchanges" do
    input = Automotive::Domain::InputRecord.new(source_identifier: 1, sku: "FSX-5840301", brand_text: "FRACO",
      category_text: "JUEGO DE EMPAQUES", description: "QJC20G FS-001225 NISSAN KA24E",
      structured_fields: { "source_row" => [ 1, "FSX-5840301" ] }, metadata: { "sheet" => "Origen", "row" => 2 })

    result = described_class.new.call(input)
    expect(result.fetch(:facts)).to include(a_hash_including("type" => "reference_candidate", "value" => "FS-001225", "confidence" => "candidate"))
    expect(result.fetch(:product)).not_to have_key("interchanges")
  end

  it "extracts the same description facts for an unseen SKU" do
    input = Automotive::Domain::InputRecord.new(source_identifier: 2, sku: "UNSEEN-987", brand_text: "OTHER",
      category_text: "JUEGO DE EMPAQUES", description: "QJC20G FS-001225 NISSAN KA24E",
      structured_fields: { "source_row" => [ 2, "UNSEEN-987" ] }, metadata: { "sheet" => "Origen", "row" => 7 })

    result = described_class.new.call(input)
    expect(result.fetch(:product).fetch("sku")).to eq("UNSEEN-987")
    expect(result.fetch(:facts)).to include(a_hash_including("type" => "engine_code_candidate", "value" => "KA24E"))
    expect(result.fetch(:facts)).to include(a_hash_including("type" => "reference_candidate", "value" => "FS-001225"))
  end
end
