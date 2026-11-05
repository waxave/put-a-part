require "rails_helper"

RSpec.describe VehicleReferenceRecord do
  let(:dataset) do
    VehicleReferenceDataset.create!(source_key: "fixture", source_version: "1", artifact_name: "fixture.jsonl",
      sha256: "a" * 64)
  end

  it "retains source identity and permits incomplete vehicle granularity" do
    record = described_class.create!(vehicle_reference_dataset: dataset, record_type: "vehicle_model",
      source_record_id: "model-1", normalizer_version: "1", content_sha256: "b" * 64,
      raw_record: { "model" => "Roadster" }, normalized_record: { "make" => "Example", "model" => "Roadster" })

    expect(record.reload.resolution_status).to eq("unresolved")
    expect(record.vehicle_configuration).to be_nil
  end

  it "does not allow a source record identity to be repeated in one dataset" do
    attributes = { vehicle_reference_dataset: dataset, record_type: "vehicle_model", source_record_id: "model-1",
      normalizer_version: "1", content_sha256: "b" * 64, raw_record: {}, normalized_record: {} }
    described_class.create!(attributes)

    expect(described_class.new(attributes)).not_to be_valid
  end
end
