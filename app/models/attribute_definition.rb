class AttributeDefinition < ApplicationRecord
  has_many :catalog_assertions, dependent: :restrict_with_exception

  before_validation do
    self.name = name.to_s.strip
    self.normalized_name = name.downcase.gsub(/\s+/, " ")
  end

  validates :name, :normalized_name, :catalog_key, presence: true
  validates :normalized_name, uniqueness: { scope: :attribute_class }
  validates :catalog_key, uniqueness: true
end
