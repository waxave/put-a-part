require "rails_helper"

RSpec.describe EnrichmentRequest, type: :model do
  it "persists a queued research request separately from the processing run" do
    run = ProcessingRun.create!(status: "completed_with_warnings")
    record = run.processing_records.create!(source_sheet: "Origen", source_row: 2, source_sku: "RM-152")
    request = described_class.create!(processing_record: record, source_key: "rexite")

    expect(request.reload.status).to eq("queued")
    expect(run.reload.status).to eq("completed_with_warnings")
  end
end
