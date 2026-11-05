class VehicleConfiguration < ApplicationRecord
  belongs_to :vehicle_model
  has_many :catalog_assertions, dependent: :restrict_with_exception
  has_many :vehicle_candidate_matches, dependent: :destroy

  validates :model_year, numericality: { only_integer: true, greater_than_or_equal_to: 1886, less_than_or_equal_to: 2100 }
end
