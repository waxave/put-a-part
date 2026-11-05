module Etl
  class ReprocessRun
    class InvalidRun < StandardError; end

    def call(original, knowledge_release_id: nil)
      unless original.terminal? && original.input_file.attached?
        raise InvalidRun, I18n.t("errors.run_not_finished")
      end

      selected_id = knowledge_release_id.presence || original.knowledge_release_id
      if selected_id.present? && selected_id != "empty-v1" && !KnowledgeRelease.exists?(id: selected_id)
        raise InvalidRun, I18n.t("errors.release_missing")
      end
      run = ProcessingRun.create!(format_key: original.format_key, knowledge_release_id: selected_id, metadata: { "reprocessed_from_id" => original.id })
      run.input_file.attach(original.input_file.blob)
      ProcessCatalogJob.perform_later(run.id)
      run
    rescue StandardError => error
      run&.update!(status: "failed", stage: "failed", last_error_code: error.class.name, last_error_message: I18n.t("errors.queue_failed"), finished_at: Time.current)
      raise
    end
  end
end
