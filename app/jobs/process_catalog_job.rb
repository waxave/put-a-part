class ProcessCatalogJob < ApplicationJob
  queue_as :etl

  retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
    run = ProcessingRun.find_by(id: job.arguments.first)
    run&.fail_after_retries!(error)
  end
  discard_on Etl::FormatRegistry::UnknownFormat, Etl::FormatRegistry::AmbiguousFormat

  def perform(run_id)
    run = ProcessingRun.find(run_id)
    Etl::Pipeline.call(run, defer_export: true)
    return unless run.reload.status == "processing" && run.stage == "researching"

    enqueue_research(run)
    FinalizeCatalogRunJob.perform_later(run.id)
  end

  private

  # The run remains processing until all research attempts settle and export is published.
  def enqueue_research(run)
    run.reload
    CatalogIntelligence::QueueAutofactsResearch.call(run)
  rescue StandardError => error
    Rails.logger.error("Autofacts research enqueue failed for run #{run.id}: #{error.class}: #{error.message}")
    run.processing_records.each do |record|
      request = record.enrichment_requests.find_by(source_key: CatalogIntelligence::QueueAutofactsResearch::SOURCE_KEY)
      request&.update!(status: "failed", finished_at: Time.current, last_error_code: error.class.name,
        last_error_message: "Autofacts research could not be queued.")
    end
  end
end
