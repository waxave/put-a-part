class KnowledgeReleaseAssertion < ApplicationRecord
  belongs_to :knowledge_release
  belongs_to :catalog_assertion

  validates :catalog_assertion_id, uniqueness: { scope: :knowledge_release_id }

  def readonly?
    persisted? || super
  end
end
