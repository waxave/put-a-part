class CatalogProductCategory < ApplicationRecord
  has_many :catalog_parts, dependent: :restrict_with_exception

  before_validation do
    self.name = name.to_s.strip
    self.normalized_name = name.downcase.gsub(/\s+/, " ")
  end

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: true
end
