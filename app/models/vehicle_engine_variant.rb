class VehicleEngineVariant < ApplicationRecord
  belongs_to :vehicle_generation

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :vehicle_generation_id }
  validates :cylinder_count, :displacement_cc, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
