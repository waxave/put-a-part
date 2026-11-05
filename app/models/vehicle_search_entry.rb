class VehicleSearchEntry < ApplicationRecord
  belongs_to :vehicle_make, optional: true
  belongs_to :vehicle_model, optional: true
  belongs_to :vehicle_configuration, optional: true
  belongs_to :vehicle_generation, optional: true
  belongs_to :vehicle_engine_variant, optional: true

  validates :entry_type, :display_text, :normalized_text, presence: true
  validate :has_exactly_one_catalog_entity

  scope :full_text, ->(query) {
    where("search_vector @@ websearch_to_tsquery('simple', ?)", query.to_s)
  }

  private

  def has_exactly_one_catalog_entity
    references = [ vehicle_make_id, vehicle_model_id, vehicle_configuration_id, vehicle_generation_id,
      vehicle_engine_variant_id ].count(&:present?)
    errors.add(:base, "must reference exactly one catalog entity") unless references == 1
  end
end
