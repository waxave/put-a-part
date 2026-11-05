require "rails_helper"

RSpec.describe ProcessingRun, type: :model do
  it "starts queued and exposes the input and output attachments" do
    run = described_class.create!

    expect(run.status).to eq("queued")
    expect(run.stage).to eq("queued")
    expect(run.input_file).not_to be_attached
    expect(run.output_file).not_to be_attached
  end

  it "recognizes completed and failed runs as terminal" do
    expect(described_class.new(status: "completed")).to be_terminal
    expect(described_class.new(status: "failed")).to be_terminal
    expect(described_class.new(status: "queued")).not_to be_terminal
  end

  it "cancels queued runs immediately and requests cancellation for active runs" do
    queued = described_class.create!
    queued.request_cancellation!
    expect(queued.reload.status).to eq("canceled")
    expect(queued.finished_at).to be_present

    active = described_class.create!(status: "processing", stage: "extracting")
    active.request_cancellation!
    expect(active.reload.status).to eq("cancel_requested")
    expect(active.finished_at).to be_nil
  end

  it "does not change a completed run when cancellation is requested" do
    run = described_class.create!(status: "completed", stage: "completed")
    run.request_cancellation!
    expect(run.reload.status).to eq("completed")
  end

  it "does not overwrite cancellation when retries are exhausted" do
    run = described_class.create!(status: "cancel_requested")
    run.fail_after_retries!(IOError.new("failure"))

    expect(run.reload.status).to eq("canceled")
    expect(run.finished_at).to be_present
  end
end
