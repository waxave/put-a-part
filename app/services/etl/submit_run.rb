require "zip"

module Etl
  class SubmitRun
    include ServiceCall

    class InvalidUpload < StandardError; end
    MAX_BYTES = 20.megabytes
    MAX_EXPANDED_BYTES = 100.megabytes
    MAX_ENTRIES = 1_000

    def call(upload, format_key: nil)
      unless upload.respond_to?(:original_filename) && upload.respond_to?(:size) && upload.original_filename.downcase.end_with?(".xlsx") && upload.size.between?(1, MAX_BYTES)
         raise InvalidUpload, I18n.t("errors.upload_invalid")
      end
      validate_archive!(upload)
      if format_key.present? && !Etl::FormatRegistry.registered?(format_key)
        raise InvalidUpload, "The selected supplier profile is not available."
      end

      run = ProcessingRun.create!(format_key: format_key.presence)
      run.input_file.attach(upload)
      ProcessCatalogJob.perform_later(run.id)
      run
    rescue StandardError => error
      run&.update!(status: "failed", stage: "failed", last_error_code: error.class.name, last_error_message: "Could not queue the run.", finished_at: Time.current)
      raise
    end

    private

    def validate_archive!(upload)
      Zip::File.open(upload.tempfile.path) do |archive|
        entries = archive.entries
        names = entries.map(&:name)
        valid_names = names.all? { |name| !name.start_with?("/", "\\") && !name.split(/[\\\/]/).include?("..") }
        unless entries.length <= MAX_ENTRIES && entries.sum(&:size) <= MAX_EXPANDED_BYTES && valid_names && names.include?("xl/workbook.xml") && names.include?("[Content_Types].xml")
           raise InvalidUpload, I18n.t("errors.upload_archive_invalid")
        end
      end
    rescue Zip::Error
       raise InvalidUpload, I18n.t("errors.upload_not_xlsx")
    end
  end
end
