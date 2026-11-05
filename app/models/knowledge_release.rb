class KnowledgeRelease < ApplicationRecord
  has_many :knowledge_release_assertions, dependent: :restrict_with_exception
  has_many :catalog_assertions, through: :knowledge_release_assertions

  def readonly?
    persisted?
  end
end
