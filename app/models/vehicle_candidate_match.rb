class VehicleCandidateMatch < ApplicationRecord
  belongs_to :vehicle_candidate
  belongs_to :vehicle_configuration

  validates :external_system, :source_version, :match_reason, presence: true
end
