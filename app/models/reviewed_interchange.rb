class ReviewedInterchange < ApplicationRecord
  belongs_to :catalog_observation
  validates :reference, :brand, :evidence_url, presence: true
end
