class VehicleGeneration < ApplicationRecord
  belongs_to :vehicle_model
  has_many :vehicle_engine_variants, dependent: :restrict_with_exception

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :vehicle_model_id }
  validates :year_start, :year_end, numericality: { only_integer: true, greater_than_or_equal_to: 1886, less_than_or_equal_to: 2100 }, allow_nil: true
  validate :year_range_is_ordered

  private

  def year_range_is_ordered
    return if year_start.nil? || year_end.nil? || year_end >= year_start

    errors.add(:year_end, "must be greater than or equal to start year")
  end
end
