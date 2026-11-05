module CatalogIntelligence
  class MarkAssertionReviewed
    def call(observation, claim_index:, value:)
      candidate = VehicleCandidate.find_by(catalog_observation: observation, claim_index: claim_index)
      if candidate && value.is_a?(Hash)
        year = value["year"]
        candidate.update!(make_candidate: value["manufacturer"], model_candidate: value["model"],
          model_year_start: year, model_year_end: year, parse_status: "reviewed")
      end

      assertion = CatalogAssertion.find_by(catalog_observation: observation, claim_index: claim_index)
      return unless assertion

      assertion.update!(status: "reviewed", reviewed_value: value)
    end
  end
end
