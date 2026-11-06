require "rails_helper"

RSpec.describe CatalogIntelligence::PersistExtraction do
  it "persists exact part variants and description candidates without promoting them to fitments" do
    run = ProcessingRun.create!
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "2C4516+STD",
      normalized_product: { "brand" => "HASTINGS", "category" => "ANILLOS", "description" => "NISSAN SENTRA 99/04 QR20DE" },
      facts: Automotive::ProductExtractor.call(Automotive::Domain::InputRecord.new(source_identifier: nil, sku: "2C4516+STD",
        brand_text: "HASTINGS", category_text: "ANILLOS", description: "NISSAN SENTRA 99/04 QR20DE",
        structured_fields: { "source_row" => [] }, metadata: { "sheet" => "Origen", "row" => 2 })).fetch(:facts))

    part = described_class.call(record)
    other_variant = run.processing_records.create!(source_sheet: "Origen", source_row: 3, source_sku: "2C4516+20",
      normalized_product: record.normalized_product.merge("sku" => "2C4516+20"), facts: record.facts)
    other_part = described_class.call(other_variant)

    expect(part.part_number).to eq("2C4516+STD")
    expect(other_part.part_number).to eq("2C4516+20")
    expect(part.id).not_to eq(other_part.id)
    range = record.catalog_assertions.find_by!(assertion_type: "year_range_candidate")
    expect(range.value).to include("start_year" => 1999, "end_year" => 2004, "century_policy" => "two_centuries_cutoff_30_v1")
    vehicle = record.catalog_assertions.find_by!(assertion_type: "vehicle_candidate")
    expect(vehicle.value["value"]).to include("make" => "Nissan", "model" => "SENTRA")
    expect(record.catalog_assertions.where(status: "candidate").count).to eq(record.facts.length)
    expect(record.catalog_assertions.where(status: "verified")).to be_empty
  end

  it "persists catalog reference leads as related-part candidates, not verified interchanges" do
    run = ProcessingRun.create!
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "BRAND" })
    observation = record.catalog_observations.create!(source_key: "rockauto", source_url: "https://www.rockauto.com/en/partsearch/", source_sku: "X-1",
      claims: [ { "type" => "reference_candidate", "raw_value" => "OTHER | Y-2", "brand" => "OTHER", "part_number" => "Y-2" } ])

    CatalogIntelligence::PersistObservation.call(observation)
    assertion = record.catalog_assertions.sole
    expect(assertion).to have_attributes(assertion_type: "interchange_candidate", status: "candidate")
    expect(assertion.catalog_part.part_number).to eq("X-1")
    expect(assertion.related_catalog_part.part_number).to eq("Y-2")
  end

  it "backfills existing JSON facts and observations idempotently without changing their source records" do
    run = ProcessingRun.create!
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 4, source_sku: "RM-152",
      normalized_product: { "sku" => "RM-152", "brand" => "REXITE", "category" => "Parts" },
      facts: [ { "type" => "year_range_candidate", "value" => "99/04", "raw_value" => "99/04", "start_year" => 1999,
        "end_year" => 2004, "confidence" => "candidate", "parser_id" => "description", "rule_version" => "1.2.0" } ])
    observation = record.catalog_observations.create!(source_key: "rexite", source_sku: "RM-152", source_url: "https://rexite.net/producto/example/",
      claims: [ { "type" => "application_candidate", "raw_value" => "Nissan Sentra 2004", "suggested_fields" => { "manufacturer" => "Nissan", "model" => "Sentra", "year" => 2004 } } ])
    ReviewedApplication.create!(catalog_observation: observation, claim_index: 0, manufacturer: "Nissan", model: "Sentra", year: 2004)
    original_facts = record.facts.deep_dup

    first = CatalogIntelligence::BackfillAutomotiveKnowledge.new(batch_size: 1).call
    first_assertion_count = record.catalog_assertions.count
    second = CatalogIntelligence::BackfillAutomotiveKnowledge.new(batch_size: 1).call

    expect(first).to eq(records: 1, observations: 1)
    expect(second).to eq(records: 1, observations: 1)
    expect(record.catalog_assertions.count).to eq(first_assertion_count)
    expect(record.catalog_assertions.find_by!(assertion_type: "application_candidate")).to have_attributes(status: "reviewed")
    expect(record.vehicle_candidates.sole).to have_attributes(make_candidate: "Nissan", model_candidate: "Sentra", model_year_start: 2004, parse_status: "reviewed")
    expect(record.reload.facts).to eq(original_facts)
  end
end
