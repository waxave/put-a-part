require "digest"
require "stringio"
require "roo"
require Rails.root.join("lib/catalog/workbook_contract")

module Etl
  class Pipeline
    def self.call(run, defer_export: false)
      new(run, defer_export: defer_export).call
    end

    def self.finalize(run)
      new(run).finalize
    end

    class Canceled < StandardError; end
    CHECKPOINT_INTERVAL = 25

    def initialize(run, defer_export: false)
      @run = run
      @defer_export = defer_export
    end

    def call
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        lock_id = connection.quote(@run.id)
        acquired = connection.select_value("SELECT pg_try_advisory_lock(hashtextextended(#{lock_id}, 0))")
        return unless acquired

        begin
          process unless @run.reload.terminal?
        ensure
          connection.execute("SELECT pg_advisory_unlock(hashtextextended(#{lock_id}, 0))")
        end
      end
    end

    def finalize
      export
    end

    private

    def process
      return unless start_processing!

      @run.input_file.open do |file|
        workbook = Roo::Spreadsheet.open(file.path, extension: :xlsx)
        profile = FormatRegistry.new.resolve(workbook, key: @run.format_key)
        context = ExecutionContext.new(format_key: profile.class::KEY, format_version: profile.class::VERSION,
          ruleset_version: Automotive::ProductExtractor::RULESET_VERSION, knowledge_release_id: @run.knowledge_release_id.presence || "empty-v1",
          export_schema_version: Etl::Exporters::XlsxExporter::SCHEMA_VERSION,
          attribute_catalog_version: Etl::Exporters::XlsxExporter::ATTRIBUTE_CATALOG_VERSION)
        if @run.format_version.present? && context.to_h.any? { |key, value| @run.public_send(key) != value }
          raise FormatRegistry::UnknownFormat, "Pinned processing versions are no longer available"
        end
        @run.update!(context.to_h.merge(input_sha256: Digest::SHA256.file(file.path).hexdigest, stage: "extracting", progress_percent: [ @run.progress_percent, 10 ].max))
        entries = @run.knowledge_release_id == "empty-v1" ? [] : KnowledgeRelease.find(@run.knowledge_release_id).entries
        @knowledge_entries = entries
        process_records(profile, workbook)
      end
      check_cancellation!
      if @defer_export
        @run.update!(stage: "researching", progress_percent: [ @run.progress_percent, 80 ].max)
      else
        export
      end
    rescue Canceled
      nil
    rescue FormatRegistry::UnknownFormat, FormatRegistry::AmbiguousFormat => error
      canceled = false
      @run.with_lock do
        if @run.status == "cancel_requested"
          mark_canceled!
          canceled = true
        elsif @run.status == "canceled"
          canceled = true
        else
          update_record_counts!
          @run.update!(status: "failed", stage: "failed", last_error_code: error.class.name, last_error_message: error.message.truncate(500), finished_at: Time.current)
        end
      end
      return if canceled

      raise
    rescue StandardError => error
      canceled = false
      @run.with_lock do
        if @run.status == "cancel_requested"
          mark_canceled!
          canceled = true
        elsif @run.status == "canceled"
          canceled = true
        else
          update_record_counts!
          @run.update!(status: "queued", last_error_code: error.class.name, last_error_message: "Processing interrupted; retry scheduled.")
        end
      end
      return if canceled

      raise
    end

    def start_processing!
      @run.with_lock do
        if @run.status == "cancel_requested"
          mark_canceled!
          return false
        end
        return false if @run.terminal?

        @run.update!(status: "processing", stage: "detecting", started_at: @run.started_at || Time.current, attempt_count: @run.attempt_count + 1)
      end
      true
    end

    def check_cancellation!
      return unless @run.reload.status.in?(%w[cancel_requested canceled])

      @run.with_lock { mark_canceled! if @run.status == "cancel_requested" }
      raise Canceled
    end

    def mark_canceled!
      update_record_counts!
      @run.update!(status: "canceled", stage: "canceled", finished_at: Time.current)
    end

    def process_records(profile, workbook)
      processed_since_checkpoint = 0
      profile.each_record(workbook) do |input|
        check_cancellation!
        extracted = Automotive::ProductExtractor.call(input)
        product = extracted.fetch(:product)
        product["applications"] = Automotive::Resolvers::ApplicationResolver.call(entries: @knowledge_entries,
          source_sheet: input.metadata.fetch("sheet"), source_row: input.metadata.fetch("row"), sku: product["sku"], brand: product["brand"])
        resolved_attributes = Automotive::Resolvers::AttributeResolver.call(entries: @knowledge_entries, sku: product["sku"],
          brand: product["brand"], facts: extracted.fetch(:facts))
        product["attributes"] = resolved_attributes.fetch(:attributes)
        resolved_catalog = Automotive::Resolvers::CatalogFieldResolver.call(entries: @knowledge_entries, sku: product["sku"], brand: product["brand"])
        product["catalog_fields"] = resolved_catalog.fetch(:fields)
        product["interchanges"] = Automotive::Resolvers::InterchangeResolver.call(entries: @knowledge_entries, sku: product["sku"], brand: product["brand"])
        has_conflicts = resolved_attributes.fetch(:conflicts).any? || resolved_catalog.fetch(:conflicts).any?
        message = "Conflicting source evidence requires review; disputed values were not exported." if has_conflicts
        record = @run.processing_records.find_or_initialize_by(source_sheet: input.metadata.fetch("sheet"), source_row: input.metadata.fetch("row"))
        ProcessingRecord.transaction do
          record.update!(source_sku: input.sku, status: has_conflicts ? "warning" : "successful", normalized_product: product,
            facts: extracted.fetch(:facts), unresolved: message ? [ message ] : [], processed_at: Time.current)
          if resolved_attributes.fetch(:conflicts).any?
            conflict = @run.processing_issues.find_or_initialize_by(processing_record: record, stage: "resolving", code: "attribute_conflict")
            conflict.update!(severity: "warning", message: "Conflicting attribute evidence requires review; catalog attributes were not exported.",
              details: { "source_sheet" => input.metadata.fetch("sheet"), "source_row" => input.metadata.fetch("row"), "source_sku" => input.sku })
          end
          if resolved_catalog.fetch(:conflicts).any?
            conflict = @run.processing_issues.find_or_initialize_by(processing_record: record, stage: "resolving", code: "catalog_field_conflict")
            conflict.update!(severity: "warning", message: "Conflicting catalog evidence requires review; disputed catalog fields were not exported.",
              details: { "source_sheet" => input.metadata.fetch("sheet"), "source_row" => input.metadata.fetch("row"), "source_sku" => input.sku })
          end
        end
        CatalogIntelligence::PersistExtraction.call(record)
        product["extraction_fallback"] = CatalogIntelligence::BuildExtractedPartResult.call(record, product: product)
        record.update!(normalized_product: product)
        processed_since_checkpoint += 1
        if processed_since_checkpoint >= CHECKPOINT_INTERVAL
          update_record_counts!
          processed_since_checkpoint = 0
        end
      end
      check_cancellation!
      update_record_counts!
      @run.update!(stage: "extracting", progress_percent: [ @run.progress_percent, 75 ].max)
    end

    def update_record_counts!
      counts = @run.processing_records.group(:status).count
      total = counts.values.sum
      @run.update!(total_records: [ @run.total_records, total ].max, processed_records: total,
        successful_records: counts.fetch("successful", 0), warning_records: counts.fetch("warning", 0),
        failed_records: counts.fetch("failed", 0))
    end

    def export
      records = @run.processing_records.order(:source_sheet, :source_row).to_a
      bytes = Etl::Exporters::XlsxExporter.call(records)
      check_cancellation!
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(bytes), filename: "catalog-#{@run.id}.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      published = @run.with_lock do
        if @run.status == "cancel_requested"
          mark_canceled!
          false
        elsif !@run.terminal?
          @run.output_file.attach(blob)
          status = @run.warning_records.positive? ? "completed_with_warnings" : "completed"
          @run.update!(status: status, stage: "completed", progress_percent: 100, finished_at: Time.current,
            last_error_code: nil, last_error_message: nil, metadata: @run.metadata.merge("output_sha256" => Digest::SHA256.hexdigest(bytes)))
          true
        end
      end
    ensure
      blob&.purge unless published
    end
  end
end
