class ProcessCatalogJob < ApplicationJob
  queue_as :etl

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    run = ProcessingRun.find_by(id: job.arguments.first)
    run&.fail_after_retries!(error)
  end
  discard_on Etl::FormatRegistry::UnknownFormat, Etl::FormatRegistry::AmbiguousFormat

  def perform(run_id)
    run = ProcessingRun.find(run_id)
    Etl::Pipeline.new(run).call
  end
end
