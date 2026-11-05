class CatalogAssertion < ApplicationRecord
  STATUSES = %w[candidate reviewed verified conflict rejected].freeze
  TYPES = %w[
    part_candidate vehicle_candidate year_range_candidate application_candidate application
    interchange_candidate interchange attribute_candidate attribute catalog_field_candidate catalog_field
    engine_candidate cylinder_count_candidate displacement_liters_candidate valve_count_candidate camshaft_candidate
  ].freeze

  belongs_to :processing_record
  belongs_to :catalog_part, optional: true
  belongs_to :catalog_observation, optional: true
  belongs_to :vehicle_candidate, optional: true
  belongs_to :attribute_definition, optional: true
  belongs_to :vehicle_configuration, optional: true
  belongs_to :related_catalog_part, class_name: "CatalogPart", optional: true

  validates :assertion_key, :assertion_type, :source_key, presence: true
  validates :assertion_key, uniqueness: { scope: :processing_record_id }
  validates :assertion_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
end
