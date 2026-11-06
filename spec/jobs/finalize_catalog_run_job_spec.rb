require "rails_helper"

RSpec.describe FinalizeCatalogRunJob, type: :job do
  it "does not export or complete a run while any research request is pending" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    record.enrichment_requests.create!(source_key: "autofacts", status: "queued")
    allow(CatalogIntelligence::ApplyResearchFallback).to receive(:call)

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "processing", stage: "researching")
    expect(run.output_file).not_to be_attached
    expect(CatalogIntelligence::ApplyResearchFallback).not_to have_received(:call)
  end

  it "finalizes after research requests reach a terminal state" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    allow(CatalogIntelligence::ApplyResearchFallback).to receive(:call)
    allow(Etl::Pipeline).to receive(:finalize)

    described_class.perform_now(run.id)

    expect(run.reload.stage).to eq("finalizing")
    expect(CatalogIntelligence::ApplyResearchFallback).to have_received(:call).with(run)
    expect(Etl::Pipeline).to have_received(:finalize).with(run)
  end
end
