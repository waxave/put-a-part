class VehicleCandidate < ApplicationRecord
  STATUSES = %w[candidate interpreted unresolved reviewed conflict rejected].freeze
  RESOLUTION_STATUSES = %w[unresolved matched partial ambiguous no_match].freeze

  belongs_to :processing_record
  belongs_to :catalog_part, optional: true
  belongs_to :catalog_observation, optional: true
  belongs_to :vehicle_configuration, optional: true
  has_one :catalog_assertion, dependent: :nullify
  has_many :vehicle_candidate_matches, dependent: :destroy
  has_many :matched_vehicle_configurations, through: :vehicle_candidate_matches, source: :vehicle_configuration

  validates :assertion_key, :source_key, :raw_text, presence: true
  validates :assertion_key, uniqueness: { scope: :processing_record_id }
  validates :parse_status, inclusion: { in: STATUSES }
  validates :resolution_status, inclusion: { in: RESOLUTION_STATUSES }
  validates :model_year_start, :model_year_end,
    numericality: { only_integer: true, greater_than_or_equal_to: 1886, less_than_or_equal_to: 2100 }, allow_nil: true
end
