class VehicleReferenceDataset < ApplicationRecord
  has_many :vehicle_reference_imports, dependent: :restrict_with_exception
  has_many :vehicle_reference_records, dependent: :restrict_with_exception

  validates :source_key, :source_version, :artifact_name, :sha256, presence: true
  validates :sha256, format: { with: /\A[0-9a-f]{64}\z/i }
  validates :source_version, uniqueness: { scope: [ :source_key, :sha256 ] }
end
