class CatalogPart < ApplicationRecord
  belongs_to :automotive_brand
  belongs_to :catalog_product_category, optional: true
  has_many :catalog_assertions, dependent: :restrict_with_exception
  has_many :part_identifiers, dependent: :restrict_with_exception
  has_many :related_assertions, class_name: "CatalogAssertion", foreign_key: :related_catalog_part_id, dependent: :restrict_with_exception

  before_validation :normalize_part_number

  validates :part_number, :part_number_key, presence: true
  validates :part_number_key, uniqueness: { scope: :automotive_brand_id }

  private

  def normalize_part_number
    self.part_number = part_number.to_s.strip
    # Case and whitespace normalize; suffixes/punctuation remain identity-significant.
    self.part_number_key = part_number.upcase.gsub(/\s+/, "")
  end
end
