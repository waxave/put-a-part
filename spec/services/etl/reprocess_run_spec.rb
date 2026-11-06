require "rails_helper"

RSpec.describe Etl::ReprocessRun do
  include ActiveJob::TestHelper

  it "rejects a run without an input attachment" do
    original = ProcessingRun.create!(status: "failed")

    expect { described_class.call(original) }.to raise_error(described_class::InvalidRun)
    expect(ProcessingRun.count).to eq(1)
  end

  it "rejects a run that is still processing" do
    original = ProcessingRun.create!(status: "processing")
    path = Rails.root.join("spec/fixtures/files/input_prueba.xlsx")
    original.input_file.attach(io: File.open(path, "rb"), filename: "input_prueba.xlsx")

    expect { described_class.call(original) }.to raise_error(described_class::InvalidRun)
    expect(enqueued_jobs).to be_empty
  end

  it "can pin an existing historical release without changing it" do
    original = ProcessingRun.create!(status: "completed")
    path = Rails.root.join("spec/fixtures/files/input_prueba.xlsx")
    original.input_file.attach(io: File.open(path, "rb"), filename: "input_prueba.xlsx")
    release = KnowledgeRelease.create!(entries: [])
    expect do
      run = described_class.call(original, knowledge_release_id: release.id)
      expect(run.knowledge_release_id).to eq(release.id)
    end.to have_enqueued_job(ProcessCatalogJob).on_queue("etl")
    run = ProcessingRun.order(:created_at).last
    expect(run.knowledge_release_id).to eq(release.id)
    expect(original.reload.knowledge_release_id).to be_nil
  end
end
