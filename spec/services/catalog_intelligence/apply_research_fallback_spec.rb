require "rails_helper"

RSpec.describe CatalogIntelligence::ApplyResearchFallback do
  it "puts extracted vehicle and reference candidates into the workbook-backed fields" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand", "category" => "Piston Ring", "description" => "Piston Ring" },
      facts: [
        { "type" => "vehicle_candidate", "value" => { "make" => "Nissan", "model" => "Altima", "year_start" => 2007, "year_end" => 2008 }, "confidence" => "candidate" },
        { "type" => "reference_candidate", "value" => "ABC-123", "confidence" => "candidate" }
      ])

    described_class.call(run)

    product = record.reload.normalized_product
    expect(product["applications"]).to include(a_hash_including("manufacturer" => "Nissan", "model" => "Altima", "year" => 2007,
      "evidence_status" => "candidate"))
    expect(product["interchanges"]).to include(a_hash_including("interchange_reference" => "ABC-123", "evidence_status" => "candidate"))
    expect(product["subcategory"]).to be_present
    expect(product.dig("catalog_fields", "system", "value")).to eq("Motor")
    expect(product.dig("extraction_fallback", "applications")).to include(a_hash_including("make" => "Nissan", "model" => "Altima", "year" => 2007))
    expect(product["extraction_fallback"].keys).to match_array(Autofacts::Part.new(
      brand_slug: nil, part_number: "X-1", brand: "Brand", description: "Piston Ring", category: nil, subcategory: nil,
      grade: nil, url: nil, attributes: [], attributes_count: 0, countries: [], applications: [], applications_count: 0,
      years_range: nil
    ).to_h.keys.map(&:to_s))
  end

  it "derives a Spanish vehicle category from one consistent local vehicle kind" do
    make = VehicleMake.create!(name: "Nissan")
    VehicleModel.create!(vehicle_make: make, name: "Altima", vehicle_kind: "car")
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-2",
      normalized_product: { "sku" => "X-2", "brand" => "Brand", "category" => "PISTONES" },
      facts: [ { "type" => "vehicle_candidate", "value" => { "make" => "Nissan", "model" => "Altima", "year_start" => 2010, "year_end" => 2010 }, "confidence" => "candidate" } ])

    described_class.call(run)

    expect(record.reload.normalized_product.dig("catalog_fields", "category", "value")).to eq("Automóvil")
  end

  it "fills empty catalog taxonomy fields from the stored Autofacts result translations" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-3",
      normalized_product: { "sku" => "X-3", "brand" => "Brand", "catalog_fields" => {
        "system" => { "value" => "" }, "subsystem" => { "value" => nil }
      } })
    request = record.enrichment_requests.create!(source_key: CatalogIntelligence::QueueAutofactsResearch::SOURCE_KEY,
      status: "completed", result_data: {
        "category" => { "name" => "Engine", "translations" => { "es" => "Motor" } },
        "subcategory" => { "name" => "Piston Ring", "translations" => { "es" => "Segmento de pistón" } }
      })
    client = instance_double(Autofacts::Client, search_subcategories: [], categories: [], close: nil)
    allow(Autofacts::Client).to receive(:new).and_return(client)

    described_class.call(run)

    fields = record.reload.normalized_product.fetch("catalog_fields")
    expect(fields.dig("system", "value")).to eq("Motor")
    expect(fields.dig("subsystem", "value")).to eq("Segmento de pistón")
    expect(request.reload.status).to eq("completed")
  end

  it "chooses the exact Spanish subcategory when a broader term returns related entries" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-4",
      normalized_product: { "sku" => "X-4", "brand" => "Brand", "category" => "BOMBA DE ACEITE" })

    described_class.call(run)

    fields = record.reload.normalized_product.fetch("catalog_fields")
    expect(fields.dig("system", "value")).to eq("Motor")
    expect(fields.dig("subsystem", "value")).to eq("Bomba de aceite")
  end

  it "uses the first returned subcategory when Autofacts returns multiple matches" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-5",
      normalized_product: { "sku" => "X-5", "brand" => "Brand", "category" => "JUEGO DE EMPAQUES" })
    subcategories = [
      Autofacts::Subcategory.new(slug: "conversion-lower-gasket-set", name: "Juego de juntas de conversión / inferior",
        translations: { "es" => "Juego de juntas de conversión / inferior" }, category: "engine"),
      Autofacts::Subcategory.new(slug: "cylinder-head-gasket-set", name: "Juego de juntas de culata",
        translations: { "es" => "Juego de juntas de culata" }, category: "engine"),
      Autofacts::Subcategory.new(slug: "engine-kit-gasket-set", name: "Juego de juntas del kit de motor",
        translations: { "es" => "Juego de juntas del kit de motor" }, category: "engine")
    ]
    category = Autofacts::Category.new(slug: "engine", name: "Motor", translations: { "es" => "Motor" })
    client = instance_double(Autofacts::Client, categories: [ category ], close: nil)
    allow(client).to receive(:search_subcategories).and_return(subcategories)
    allow(Autofacts::Client).to receive(:new).and_return(client)

    described_class.call(run)

    fields = record.reload.normalized_product.fetch("catalog_fields")
    expect(fields.dig("system", "value")).to eq("Motor")
    expect(fields.dig("subsystem", "value")).to eq("Juego de juntas de conversión / inferior")
  end

  it "maps PISTONES to the exact Spanish Autofacts taxonomy result" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-6",
      normalized_product: { "sku" => "X-6", "brand" => "Brand", "category" => "PISTONES" })
    subcategory = Autofacts::Subcategory.new(slug: "piston", name: "Pistón", translations: { "es" => "Pistón" }, category: "engine")
    category = Autofacts::Category.new(slug: "engine", name: "Motor", translations: { "es" => "Motor" })
    client = instance_double(Autofacts::Client, categories: [ category ], close: nil)
    allow(client).to receive(:search_subcategories).and_return([ subcategory ])
    allow(Autofacts::Client).to receive(:new).and_return(client)

    described_class.call(run)

    fields = record.reload.normalized_product.fetch("catalog_fields")
    expect(fields.dig("system", "value")).to eq("Motor")
    expect(fields.dig("subsystem", "value")).to eq("Pistón")
  end
end
