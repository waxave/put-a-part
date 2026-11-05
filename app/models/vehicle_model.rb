class VehicleModel < ApplicationRecord
  belongs_to :vehicle_make
  has_many :vehicle_configurations, dependent: :restrict_with_exception

  before_validation :normalize_name

  validates :name, :normalized_name, presence: true
  has_many :vehicle_generations, dependent: :restrict_with_exception

  validates :normalized_name, uniqueness: { scope: [ :vehicle_make_id, :vehicle_kind ] }

  private

  def normalize_name
    self.name = name.to_s.strip
    self.normalized_name = Automotive::Knowledge::NormalizeVehicleText.call(name)
  end
end
