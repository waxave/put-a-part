class ProcessingRun < ApplicationRecord
  has_one_attached :input_file
  has_one_attached :output_file
  has_many :processing_records, dependent: :destroy
  has_many :processing_issues, dependent: :destroy

  # Keep the retired status terminal so pre-removal runs remain safe to inspect/reprocess.
  TERMINAL_STATUSES = %w[awaiting_review completed completed_with_warnings failed canceled].freeze

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def request_cancellation!
    with_lock do
      return false if terminal?
      return true if status == "cancel_requested"

      if status == "queued"
        update!(status: "canceled", stage: "canceled", finished_at: Time.current)
      else
        update!(status: "cancel_requested")
      end
    end
    true
  end

  def fail_after_retries!(error)
    with_lock do
      return if terminal?

      if status == "cancel_requested"
        update!(status: "canceled", stage: "canceled", finished_at: Time.current)
      else
        update!(status: "failed", stage: "failed", last_error_code: error.class.name,
          last_error_message: "Processing failed after retries.", finished_at: Time.current)
      end
    end
  end
end
