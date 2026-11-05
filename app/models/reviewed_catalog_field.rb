class ReviewedCatalogField < ApplicationRecord
  belongs_to :catalog_observation

  validates :field, inclusion: { in: Automotive::Domain::CatalogFields::NAMES }
  validates :value, presence: true
end
