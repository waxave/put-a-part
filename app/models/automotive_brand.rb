class AutomotiveBrand < ApplicationRecord
  has_many :catalog_parts, dependent: :restrict_with_exception

  before_validation :normalize_name

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: true

  private

  def normalize_name
    self.name = name.to_s.strip
    self.normalized_name = name.downcase.gsub(/\s+/, " ")
  end
end
