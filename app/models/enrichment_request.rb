class EnrichmentRequest < ApplicationRecord
  belongs_to :processing_record

  validates :source_key, presence: true
  validates :status, inclusion: { in: %w[queued researching completed not_found failed] }
end
