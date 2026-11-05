module CatalogIntelligence
  class PersistObservation
    def call(observation)
      record = observation.processing_record
      part = PersistExtraction.new.call(record)

      observation.claims.each_with_index do |claim, index|
        next unless claim.is_a?(Hash)

        type = claim["type"].to_s
        related_part = persist_related_part(claim) if type == "reference_candidate"
        vehicle_candidate = persist_vehicle_candidate(observation, part, claim, index) if type == "application_candidate"
        CatalogAssertion.find_or_initialize_by(processing_record: record, assertion_key: "observation:#{observation.id}:#{index}").tap do |assertion|
          assertion.assign_attributes(catalog_part: part, catalog_observation: observation, vehicle_candidate: vehicle_candidate, assertion_type: assertion_type(type),
            related_catalog_part: related_part,
            source_key: observation.source_key, claim_index: index, raw_value: claim["raw_value"],
            value: claim.except("raw_value", "type"), evidence_url: observation.source_url, retrieved_at: observation.retrieved_at)
          assertion.save!
        end
        sync_existing_review(observation, index)
      end
    end

    private

    def persist_vehicle_candidate(observation, part, claim, index)
      record = observation.processing_record
      fields = claim["suggested_fields"].is_a?(Hash) ? claim["suggested_fields"] : (claim["fields"].is_a?(Hash) ? claim["fields"] : {})
      make = fields["manufacturer"] || fields["Make"]
      model = fields["model"] || fields["Model"]
      year = Integer(fields["year"] || fields["Year"], exception: false)
      VehicleCandidate.find_or_initialize_by(processing_record: record, assertion_key: "observation:#{observation.id}:#{index}").tap do |candidate|
        candidate.assign_attributes(catalog_part: part, catalog_observation: observation, source_key: observation.source_key, claim_index: index,
          make_candidate: make, model_candidate: model, model_year_start: year, model_year_end: year,
          engine_code_candidate: claim.dig("qualifiers", "engine"), qualifiers: claim["qualifiers"] || {}, raw_text: claim["raw_value"].to_s,
          parse_status: make.present? && model.present? && year ? "interpreted" : "candidate")
        candidate.save!
      end
    end

    def persist_related_part(claim)
      return if claim["brand"].to_s.strip.blank? || claim["part_number"].to_s.strip.blank?

      brand_name = claim["brand"].to_s.strip
      identity = FindOrCreateIdentity.new
      brand = identity.call(AutomotiveBrand, identity: { normalized_name: brand_name.downcase.gsub(/\s+/, " ") }, attributes: { name: brand_name })
      number = claim["part_number"].to_s.strip
      identity.call(CatalogPart, identity: { automotive_brand: brand, part_number_key: number.upcase.gsub(/\s+/, "") }, attributes: { part_number: number })
    end

    def assertion_type(type)
      return "application_candidate" if type == "application_candidate"
      return "interchange_candidate" if type == "reference_candidate" || type == "interchange_candidate"
      return "attribute_candidate" if type == "source_field"
      return "catalog_field_candidate" if type == "search_result"
      return "vehicle_candidate" if type.match?(/vehicle|year_range/i)

      "catalog_field_candidate"
    end

    def sync_existing_review(observation, index)
      application = ReviewedApplication.find_by(catalog_observation: observation, claim_index: index)
      if application
        MarkAssertionReviewed.new.call(observation, claim_index: index,
          value: { "manufacturer" => application.manufacturer, "model" => application.model, "year" => application.year })
      end
      attribute = ReviewedAttribute.find_by(catalog_observation: observation, claim_index: index)
      if attribute
        MarkAssertionReviewed.new.call(observation, claim_index: index,
          value: { "attribute_class" => attribute.attribute_class, "name" => attribute.name, "unit" => attribute.unit, "value" => attribute.value })
      end
      ReviewedCatalogField.where(catalog_observation: observation, claim_index: index).find_each do |field|
        MarkAssertionReviewed.new.call(observation, claim_index: index, value: { "field" => field.field, "value" => field.value })
      end
      interchange = ReviewedInterchange.find_by(catalog_observation: observation, claim_index: index)
      if interchange
        MarkAssertionReviewed.new.call(observation, claim_index: index,
          value: { "reference" => interchange.reference, "brand" => interchange.brand, "evidence_url" => interchange.evidence_url })
      end
    end
  end
end
