require "rails_helper"

RSpec.describe ProcessCatalogJob, type: :job do
  include ActiveJob::TestHelper

  it "runs the ETL pipeline on the etl queue" do
    run = ProcessingRun.create!
    allow(Etl::Pipeline).to receive(:call).with(run, defer_export: true).and_return(nil)

    described_class.perform_now(run.id)

    expect(Etl::Pipeline).to have_received(:call).with(run, defer_export: true)
    expect(described_class.queue_name).to eq("etl")
  end

  it "automatically enqueues part research after successful processing" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    allow(Etl::Pipeline).to receive(:call).with(run, defer_export: true).and_return(nil)

    expect do
      described_class.perform_now(run.id)
    end.to have_enqueued_job(AutofactsResearchJob).on_queue("imports")

    expect(record.enrichment_requests.sole).to have_attributes(status: "queued", enqueued_at: be_present)
  end

  it "keeps a completed run even if research enqueue fails" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    allow(Etl::Pipeline).to receive(:call).with(run, defer_export: true).and_return(nil)
    allow(CatalogIntelligence::QueueAutofactsResearch).to receive(:call).and_raise(RuntimeError, "queue unavailable")

    expect { described_class.perform_now(run.id) }.not_to raise_error

    expect(run.reload.status).to eq("processing")
  end
end
