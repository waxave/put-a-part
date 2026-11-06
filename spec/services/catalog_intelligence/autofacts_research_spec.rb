require "rails_helper"

RSpec.describe CatalogIntelligence::AutofactsResearch do
  let(:run) { ProcessingRun.create!(status: "completed", stage: "completed") }
  let(:record) do
    run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Hastings Manufacturing", "category" => "Parts" })
  end
  let(:request) { record.enrichment_requests.create!(source_key: "autofacts", status: "researching") }
  let(:candidate) do
    Autofacts::SearchResult.new(brand_slug: "hastings-manufacturing", part_number: "X-1",
      brand: "Hastings Manufacturing", description: "Test piston ring", url: "https://autofactsdb.com/part/hastings-manufacturing/X-1/")
  end
  let(:search_results) { Autofacts::SearchResults.new(query: "X-1", parts: [ candidate ], next_page_url: nil) }
  let(:client) { instance_double(Autofacts::Client) }

  it "fetches one exact brand match and persists its details as unverified source claims" do
    part = Autofacts::Part.new(brand_slug: "hastings-manufacturing", part_number: "X-1",
      brand: "Hastings Manufacturing", description: "Test piston ring", grade: "Aftermarket", url: candidate.url,
      category: { name: "Engine", translations: { es: "Motor" } },
      subcategory: { name: "Piston Ring", translations: { es: "Segmento de pistón" } },
      attributes: [ { class: "Ring", attribute: "Diameter", unit: "mm", value: "89" } ],
      applications: [ { year: 2007, make: "Nissan", model: "Altima", engine: "QR25DE", country_code: "US", country_alpha3: "USA" } ])
    allow(client).to receive(:find).with("X-1", page: 1).and_return(search_results)
    allow(client).to receive(:part).with("X-1", brand: "Hastings Manufacturing").and_return(part)
    allow(client).to receive(:countries).and_return([ Autofacts::Country.new(code: "US", alpha_3: "USA", name: "United States") ])
    allow(client).to receive(:close)

    described_class.call(request, client_factory: -> { client })

    expect(request.reload).to have_attributes(status: "completed", result_data: hash_including("observation_id" => be_present))
    observation = record.catalog_observations.sole
    expect(observation).to have_attributes(source_key: "autofacts", source_sku: "X-1", status: "candidate")
    expect(observation.safe_source_url).to eq(candidate.url)
    expect(record.catalog_assertions.pluck(:status).uniq).to eq([ "candidate" ])
    expect(record.vehicle_candidates.sole).to have_attributes(make_candidate: "Nissan", model_candidate: "Altima", model_year_start: 2007)
    expect(record.reload.normalized_product["applications"]).to include(a_hash_including("manufacturer" => "Nissan", "model" => "Altima", "year" => 2007))
    expect(record.normalized_product["attributes"]).to include(a_hash_including("name" => "Diameter", "value" => "89"))
    expect(record.normalized_product.dig("catalog_fields", "system", "value")).to eq("Motor")
    expect(record.normalized_product.dig("catalog_fields", "subsystem", "value")).to eq("Segmento de pistón")
    expect(record.normalized_product.dig("applications", 0, "qualifiers", "market")).to eq("USA")
    expect(record.normalized_product["interchange_origin"]).to eq("Aftermarket")
    expect(request.result_data.dig("autofacts_result", "subcategory")).to eq(part.subcategory.deep_stringify_keys)
    expect(request.result_data.dig("autofacts_result", "applications")).to eq(part.applications.map(&:deep_stringify_keys))
    expect(client).to have_received(:close)
  end

  it "does not treat a gem-normalized part variant as an exact match" do
    variant_record = record
    variant_record.update!(source_sku: "X-1+STD", normalized_product: { "sku" => "X-1+STD", "brand" => "Hastings Manufacturing" })
    allow(client).to receive(:find).with("X-1+STD", page: 1).and_return(search_results)
    allow(client).to receive(:part)
    allow(client).to receive(:close)

    described_class.call(request, phase: "find", client_factory: -> { client })

    expect(request.reload.status).to eq("ambiguous")
    expect(request.result_data.dig("candidates", 0, "part_number")).to eq("X-1")
    expect(client).not_to have_received(:part)
  end

  it "searches the AutoFactsDB index and does not match a different brand" do
    record.update!(normalized_product: { "sku" => "X-1", "brand" => "Generic Brand" })
    result = Autofacts::SearchResult.new(brand_slug: "hastings-manufacturing", part_number: "X-1",
      brand: "Hastings Manufacturing", description: "Test part", url: candidate.url)
    search = Autofacts::SearchResults.new(query: "X-1", parts: [ result ], next_page_url: nil)
    allow(client).to receive(:find).with("X-1", page: 1).and_return(search)
    allow(client).to receive(:part)
    allow(client).to receive(:close)

    described_class.call(request, phase: "find", client_factory: -> { client })

    expect(request.reload.status).to eq("ambiguous")
    expect(record.catalog_observations).to be_empty
    expect(client).not_to have_received(:part)
  end

  it "records no matches without creating a catalog observation" do
    allow(client).to receive(:find).with("X-1", page: 1)
      .and_return(Autofacts::SearchResults.new(query: "X-1", parts: [], next_page_url: nil))
    allow(client).to receive(:close)

    described_class.call(request, phase: "find", client_factory: -> { client })

    expect(request.reload.status).to eq("not_found")
    expect(record.catalog_observations).to be_empty
  end

  it "schedules fallback search when the direct part lookup has no usable result" do
    allow(client).to receive(:part).with("X-1", brand: "Hastings Manufacturing").and_raise(Autofacts::Error, "No local part")
    allow(client).to receive(:find)
    allow(client).to receive(:close)

    result = described_class.call(request, client_factory: -> { client })

    expect(result).to eq(:waiting_for_fallback)
    expect(request.reload).to have_attributes(status: "queued", enqueued_at: be_present)
    expect(request.result_data["reason_code"]).to eq("direct_part_unavailable")
    expect(client).not_to have_received(:find)
  end
end
