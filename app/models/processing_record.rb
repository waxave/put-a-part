class ProcessingRecord < ApplicationRecord
  belongs_to :processing_run
  has_many :processing_issues, dependent: :destroy
  has_many :catalog_observations, dependent: :destroy
  has_many :enrichment_requests, dependent: :destroy
  has_many :catalog_assertions, dependent: :destroy
  has_many :vehicle_candidates, dependent: :destroy
end
