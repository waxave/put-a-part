require "rails_helper"

RSpec.describe AutofactsResearchJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  it "returns a transient request failure to queued state so Active Job can retry it" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    request = record.enrichment_requests.create!(source_key: "autofacts")
    service = instance_double(CatalogIntelligence::AutofactsResearch)
    allow(CatalogIntelligence::AutofactsResearch).to receive(:call).and_raise(Autofacts::RequestError, "temporary upstream error")

    request.update!(status: "queued")
    expect { described_class.new.perform(request.id) }.to raise_error(Autofacts::RequestError)

    expect(request.reload).to have_attributes(status: "queued", attempt_count: 1,
      last_error_code: "Autofacts::RequestError", finished_at: nil)
  end

  it "waits at least 30 seconds before queuing the fallback search" do
    run = ProcessingRun.create!(status: "processing", stage: "researching")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "X-1",
      normalized_product: { "sku" => "X-1", "brand" => "Brand" })
    request = record.enrichment_requests.create!(source_key: "autofacts", status: "queued")
    allow(CatalogIntelligence::AutofactsResearch).to receive(:call) do
      request.update!(status: "queued", enqueued_at: Time.current)
      :waiting_for_fallback
    end

    travel_to(Time.current) do
      expect do
        described_class.perform_now(request.id)
      end.to have_enqueued_job(described_class).with(request.id, "find").at(30.seconds.from_now)
    end
  end
end
