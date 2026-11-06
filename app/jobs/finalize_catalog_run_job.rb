class FinalizeCatalogRunJob < ApplicationJob
  queue_as :etl

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(run_id)
    run = ProcessingRun.find_by(id: run_id)
    return unless run
    if run.status == "cancel_requested"
      run.with_lock { run.update!(status: "canceled", stage: "canceled", finished_at: Time.current) }
      return
    end
    return unless run.status == "processing" && run.stage == "researching"

    pending = run.processing_records.joins(:enrichment_requests)
      .where(enrichment_requests: { source_key: CatalogIntelligence::QueueAutofactsResearch::SOURCE_KEY })
      .where.not(enrichment_requests: { status: %w[completed not_found ambiguous failed] }).exists?
    return if pending

    claimed = run.with_lock do
      next false unless run.status == "processing" && run.stage == "researching"

      run.update!(stage: "finalizing", progress_percent: [ run.progress_percent, 95 ].max)
      true
    end
    return unless claimed

    CatalogIntelligence::ApplyResearchFallback.call(run)
    Etl::Pipeline.finalize(run)
  rescue StandardError
    run&.update!(stage: "researching") if run&.status == "processing" && run.stage == "finalizing"
    raise
  end
end
