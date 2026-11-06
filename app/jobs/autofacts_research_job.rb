require "autofacts"

class AutofactsResearchJob < ApplicationJob
  queue_as :imports

  retry_on Autofacts::RequestError, wait: :polynomially_longer, attempts: 4 do |job, error|
    request = EnrichmentRequest.find_by(id: job.arguments.first)
    if request && job.arguments.second != "find"
      request.update!(status: "queued", enqueued_at: Time.current, last_error_code: error.class.name,
        last_error_message: error.message.truncate(500), finished_at: nil)
      job.class.set(wait: 30.seconds).perform_later(request.id, "find")
    elsif request
      request.update!(status: "failed", enqueued_at: nil, last_error_code: error.class.name,
        last_error_message: error.message.truncate(500), finished_at: Time.current)
      FinalizeCatalogRunJob.perform_later(request.processing_record.processing_run_id)
    end
  end

  def perform(request_id, phase = "part")
    request = EnrichmentRequest.find_by(id: request_id)
    return unless request

    should_research = request.with_lock do
      next false unless request.status == "queued"

      request.update!(status: "researching", attempt_count: request.attempt_count + 1,
        started_at: Time.current, enqueued_at: nil, finished_at: nil, last_error_code: nil, last_error_message: nil)
      true
    end
    return unless should_research

    Rails.logger.info("Autofacts research job started request_id=#{request.id} record_id=#{request.processing_record_id} attempt=#{request.attempt_count}")
    result = CatalogIntelligence::AutofactsResearch.call(request, phase: phase)
    if result == :waiting_for_fallback
      self.class.set(wait: 30.seconds).perform_later(request.id, "find")
    else
      FinalizeCatalogRunJob.perform_later(request.processing_record.processing_run_id)
    end
  rescue Autofacts::RequestError => error
    request&.update!(status: "queued", enqueued_at: Time.current, last_error_code: error.class.name,
      last_error_message: error.message.truncate(500), finished_at: nil)
    Rails.logger.warn("Autofacts research will retry request_id=#{request&.id} error=#{error.class}: #{error.message}")
    raise
  rescue StandardError => error
    request&.update!(status: "failed", enqueued_at: nil, last_error_code: error.class.name,
      last_error_message: error.message.truncate(500), finished_at: Time.current)
    Rails.logger.error("Autofacts research job failed request_id=#{request&.id} error=#{error.class}: #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
    FinalizeCatalogRunJob.perform_later(request.processing_record.processing_run_id) if request
  end
end
