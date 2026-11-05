require "rails_helper"

RSpec.describe Automotive::Knowledge::ImportVehicleReference do
  let(:rows) do
    [
      { make_id: "1", make_name: "Nissan", model_id: "10", model_name: "Sentra", configuration_id: "100", model_year: 1999, engine_code: "QR20DE" },
      { make_id: "1", make_name: "Nissan", model_id: "10", model_name: "Sentra", configuration_id: "101", model_year: 2000, engine_code: "QR20DE" }
    ]
  end

  it "imports versioned reference identities and resolves candidates without asserting part fitment" do
    run = ProcessingRun.create!
    input = Automotive::Domain::InputRecord.new(source_identifier: nil, sku: "P-1", brand_text: "BRAND", category_text: "Parts",
      description: "NISSAN SENTRA 99/00 QR20DE", structured_fields: { "source_row" => [] }, metadata: { "sheet" => "Origen", "row" => 2 })
    extracted = Automotive::ProductExtractor.call(input)
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "P-1", normalized_product: extracted.fetch(:product), facts: extracted.fetch(:facts))
    CatalogIntelligence::PersistExtraction.new.call(record)
    candidate = record.vehicle_candidates.sole

    expect { described_class.new.call(records: rows, external_system: "VCdb", source_version: "2026-10") }
      .to change(VehicleConfiguration, :count).by(2)
    expect { described_class.new.call(records: rows, external_system: "VCdb", source_version: "2026-10") }
      .not_to change(VehicleConfiguration, :count)
    Automotive::Knowledge::ResolveVehicleCandidate.new.call(candidate, external_system: "VCdb", source_version: "2026-10")

    expect(candidate.reload).to have_attributes(resolution_status: "matched", parse_status: "candidate")
    expect(candidate.matched_vehicle_configurations.order(:model_year).pluck(:model_year)).to eq([ 1999, 2000 ])
    expect(record.catalog_assertions.pluck(:assertion_type)).not_to include("application")
  end
end
