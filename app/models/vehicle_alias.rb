class VehicleAlias < ApplicationRecord
  belongs_to :vehicle_make, optional: true
  belongs_to :vehicle_model, optional: true
  belongs_to :vehicle_configuration, optional: true
  belongs_to :vehicle_generation, optional: true
  belongs_to :vehicle_engine_variant, optional: true

  validates :alias_text, :normalized_alias, :source_key, presence: true
  validates :review_status, inclusion: { in: %w[candidate accepted rejected] }
  validate :has_exactly_one_catalog_entity

  private

  def has_exactly_one_catalog_entity
    references = [ vehicle_make_id, vehicle_model_id, vehicle_configuration_id ].count(&:present?)
    errors.add(:base, "must reference exactly one catalog entity") unless references == 1
  end
end
