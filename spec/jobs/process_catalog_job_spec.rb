require "rails_helper"

RSpec.describe ProcessCatalogJob, type: :job do
  it "runs the ETL pipeline on the etl queue" do
    run = ProcessingRun.create!
    pipeline = instance_double(Etl::Pipeline, call: nil)
    allow(Etl::Pipeline).to receive(:new).with(run).and_return(pipeline)

    described_class.perform_now(run.id)

    expect(pipeline).to have_received(:call)
    expect(described_class.queue_name).to eq("etl")
  end

end
