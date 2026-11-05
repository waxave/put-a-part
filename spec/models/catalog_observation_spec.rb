require "rails_helper"

RSpec.describe CatalogObservation, type: :model do
  it "stores source claims as candidates tied to the original processing record" do
    run = ProcessingRun.create!
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "RM-152")
    observation = described_class.create!(processing_record: record, source_key: "rexite",
      source_url: "https://rexite.net/producto/example/", source_sku: "RM-152",
      claims: [ { "type" => "application_candidate", "raw_value" => "Nissan 280ZX 1981" } ])

    expect(observation.reload.status).to eq("candidate")
    expect(observation.processing_record.processing_run).to eq(run)
    expect(observation.claims.first.fetch("type")).to eq("application_candidate")
  end

  it "only exposes links to the authorized HTTPS source on its standard port" do
    observation = described_class.new(source_key: "rexite", source_url: "https://rexite.net/producto/example/")
    expect(observation.safe_source_url).to eq(observation.source_url)
    [ "http://rexite.net/", "https://rexite.net:444/", "https://rexite.net.evil.test/", "https://rexite.net@evil.test/", "javascript:alert(1)" ].each do |url|
      observation.source_url = url
      expect(observation.safe_source_url).to be_nil
    end
  end
end
