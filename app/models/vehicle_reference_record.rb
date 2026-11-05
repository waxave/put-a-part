class VehicleReferenceRecord < ApplicationRecord
  belongs_to :vehicle_reference_dataset
  belongs_to :vehicle_reference_import, optional: true
  belongs_to :vehicle_make, optional: true
  belongs_to :vehicle_model, optional: true
  belongs_to :vehicle_configuration, optional: true
  belongs_to :vehicle_generation, optional: true
  belongs_to :vehicle_engine_variant, optional: true

  RESOLUTION_STATUSES = %w[unresolved matched partial ambiguous conflict rejected].freeze

  validates :record_type, :source_record_id, :normalizer_version, :content_sha256, presence: true
  validates :source_record_id, uniqueness: { scope: :vehicle_reference_dataset_id }
  validates :resolution_status, inclusion: { in: RESOLUTION_STATUSES }
end
