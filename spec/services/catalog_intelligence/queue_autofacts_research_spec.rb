require "rails_helper"

RSpec.describe CatalogIntelligence::QueueAutofactsResearch do
  include ActiveJob::TestHelper

  it "queues one Autofacts job per eligible record and avoids duplicate requests" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    run.processing_records.create!(source_sheet: "Origen", source_row: 3, source_sku: "X-2",
      normalized_product: { "sku" => "X-2", "brand" => "" })

    expect do
      expect(described_class.call(run)).to eq(1)
    end.to have_enqueued_job(AutofactsResearchJob).on_queue("imports")
    expect(record.enrichment_requests.count).to eq(1)
    expect(described_class.call(run)).to eq(0)
    expect(record.enrichment_requests.sole).to have_attributes(status: "queued", enqueued_at: be_present)
  end

  it "rejects runs that are not waiting for research" do
    expect do
      described_class.call(ProcessingRun.create!(status: "processing"))
    end.to raise_error(described_class::InvalidRun)
  end

  it "requeues a research request that has been stuck for more than an hour" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    request = record.enrichment_requests.create!(source_key: "autofacts", status: "researching", started_at: 2.hours.ago)

    expect do
      expect(described_class.call(run)).to eq(1)
    end.to have_enqueued_job(AutofactsResearchJob).with(request.id).on_queue("imports")
    expect(request.reload).to have_attributes(status: "queued", attempt_count: 0)
  end

  it "recovers a request when enqueueing fails and retries the enqueue on the next processing attempt" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    allow(AutofactsResearchJob).to receive(:perform_later).and_return(false)

    expect { described_class.call(run) }.to raise_error(RuntimeError, /was not enqueued/)
    request = record.enrichment_requests.sole
    expect(request).to have_attributes(status: "failed", enqueued_at: nil)

    allow(AutofactsResearchJob).to receive(:perform_later).and_call_original
    expect do
      expect(described_class.call(run)).to eq(1)
    end.to have_enqueued_job(AutofactsResearchJob).with(request.id).on_queue("imports")
    expect(request.reload).to have_attributes(status: "queued", enqueued_at: be_present)
  end
end
