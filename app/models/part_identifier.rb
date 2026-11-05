class PartIdentifier < ApplicationRecord
  belongs_to :catalog_part
  belongs_to :catalog_observation, optional: true

  before_validation do
    self.identifier_value = identifier_value.to_s.strip
    self.normalized_identifier = identifier_value.upcase.gsub(/\s+/, "")
  end

  validates :identifier_type, :identifier_value, :normalized_identifier, :source_key, presence: true
  validates :normalized_identifier, uniqueness: { scope: [ :catalog_part_id, :identifier_type ] }
end
