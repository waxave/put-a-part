class VehicleReferenceImport < ApplicationRecord
  belongs_to :vehicle_reference_dataset
  has_many :vehicle_reference_records, dependent: :restrict_with_exception

  STATUSES = %w[pending running validated completed failed cancelled].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :normalizer_version, presence: true
end
