module CatalogIntelligence
  class FindOrCreateIdentity
    def call(model, identity:, attributes: {})
      model.find_by(identity) || model.create!(attributes.merge(identity))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      model.find_by(identity) || raise
    end
  end
end
