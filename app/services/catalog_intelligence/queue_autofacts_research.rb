module CatalogIntelligence
  class QueueAutofactsResearch
    include ServiceCall

    class InvalidRun < StandardError; end

    SOURCE_KEY = "autofacts"
    STALE_RESEARCH_AFTER = 1.hour

    def call(run)
      unless run.status == "processing" && run.stage == "researching"
        raise InvalidRun, "Autofacts research is available after workbook extraction completes."
      end

      queued = 0
      run.processing_records.find_each do |record|
        product = record.normalized_product
        next if product["sku"].blank? && record.source_sku.blank?
        next if product["brand"].blank?

        request = record.enrichment_requests.create_or_find_by!(source_key: SOURCE_KEY)
        should_enqueue = request.with_lock do
          next false if request.status.in?(%w[completed not_found ambiguous])
          if request.status == "queued"
            next false if request.enqueued_at && request.enqueued_at > STALE_RESEARCH_AFTER.ago
          elsif request.status == "researching"
            next false if request.started_at && request.started_at > STALE_RESEARCH_AFTER.ago
          end

          request.update!(status: "queued", enqueued_at: nil, attempt_count: 0, last_error_code: nil,
            last_error_message: nil, started_at: nil, finished_at: nil, result_data: {})
          true
        end
        next unless should_enqueue

        enqueue!(request)
        queued += 1
      end
      queued
    end

    private

    def enqueue!(request)
      result = AutofactsResearchJob.perform_later(request.id)
      raise "Autofacts research job was not enqueued" unless result

      request.with_lock do
        request.update!(enqueued_at: Time.current) if request.status == "queued"
      end
    rescue StandardError => error
      request.update!(status: "failed", enqueued_at: nil, last_error_code: error.class.name,
        last_error_message: error.message.truncate(500), finished_at: Time.current)
      raise
    end
  end
end
