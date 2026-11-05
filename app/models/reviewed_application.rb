class ReviewedApplication < ApplicationRecord
  belongs_to :catalog_observation
  validates :manufacturer, :model, presence: true
  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1886, less_than_or_equal_to: 2100 }
end
