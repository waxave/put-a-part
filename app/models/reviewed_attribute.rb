class ReviewedAttribute < ApplicationRecord
  belongs_to :catalog_observation

  validates :attribute_class, :name, :value, presence: true
end
