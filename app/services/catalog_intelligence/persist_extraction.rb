module CatalogIntelligence
  class PersistExtraction
    def call(record)
      part = persist_part(record)
      record.facts.each_with_index do |fact, index|
        persist_assertion(record, part, fact, index)
      end
      part
    end

    private

    def persist_part(record)
      product = record.normalized_product
      source_sku = product["sku"].presence || record.source_sku
      return if source_sku.to_s.strip.blank? || product["brand"].to_s.strip.blank?

      brand_name = product["brand"].to_s.strip
      brand_key = brand_name.downcase.gsub(/\s+/, " ")
      identity = FindOrCreateIdentity.new
      brand = identity.call(AutomotiveBrand, identity: { normalized_name: brand_key }, attributes: { name: brand_name })
      part_number = source_sku.to_s.strip
      part_key = part_number.upcase.gsub(/\s+/, "")
      identity.call(CatalogPart, identity: { automotive_brand: brand, part_number_key: part_key },
        attributes: { part_number: part_number, product_category: product["category"], source_description: product["description"] })
    end

    def persist_assertion(record, part, fact, index)
      type = fact.fetch("type")
      vehicle_candidate = persist_vehicle_candidate(record, part, fact, index) if type == "vehicle_candidate"
      CatalogAssertion.find_or_initialize_by(processing_record: record, assertion_key: "description:#{index}").tap do |assertion|
        assertion.assign_attributes(catalog_part: part, vehicle_candidate: vehicle_candidate, assertion_type: assertion_type(type), source_key: "description",
          raw_value: fact["raw_value"], value: fact.except("raw_value", "confidence", "source", "parser_id", "rule_version"),
          parser_id: fact["parser_id"], ruleset_version: fact["rule_version"])
        assertion.save!
      end
    end

    def persist_vehicle_candidate(record, part, fact, index)
      value = fact["value"].is_a?(Hash) ? fact["value"] : {}
      VehicleCandidate.find_or_initialize_by(processing_record: record, assertion_key: "description:#{index}").tap do |candidate|
        candidate.assign_attributes(catalog_part: part, source_key: "description", make_candidate: value["make"], model_candidate: value["model"],
          model_year_start: value["year_start"], model_year_end: value["year_end"], engine_code_candidate: value["engine_code"],
          raw_text: fact["raw_value"].to_s, parse_status: value["year_range_status"] == "unresolved" ? "unresolved" : "candidate",
          parser_id: fact["parser_id"], ruleset_version: fact["rule_version"])
        candidate.save!
      end
    end

    def assertion_type(type)
      return type if CatalogAssertion::TYPES.include?(type)
      return "vehicle_candidate" if type.match?(/vehicle|make|model/i)
      return "interchange_candidate" if type.include?("reference")

      "attribute_candidate"
    end
  end
end
