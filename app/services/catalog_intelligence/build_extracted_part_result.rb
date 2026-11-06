module CatalogIntelligence
  class BuildExtractedPartResult
    include ServiceCall

    def call(record, product: record.normalized_product, taxonomy: nil, autofacts_result: nil)
      fields = product.fetch("catalog_fields", {})
      applications = applications_for(record)
      attributes = attributes_for(record, product)
      raw_result = (autofacts_result || {}).deep_stringify_keys

      Autofacts::Part.new(
        brand_slug: raw_result["brand_slug"],
        part_number: product["sku"].presence || record.source_sku,
        brand: product["brand"],
        description: product["description"],
        category: taxonomy_node(raw_result["category"] || taxonomy&.dig(:category), fields.dig("system", "value")),
        subcategory: taxonomy_node(raw_result["subcategory"] || taxonomy&.dig(:subcategory), fields.dig("subsystem", "value")),
        grade: raw_result["grade"],
        url: raw_result["url"],
        attributes: attributes,
        attributes_count: attributes.length,
        countries: raw_result["countries"] || [],
        applications: applications,
        applications_count: applications.length,
        years_range: years_range(applications)
      ).to_h.deep_stringify_keys
    end

    private

    def applications_for(record)
      record.facts.select { |fact| fact["type"] == "vehicle_candidate" && fact["confidence"] == "candidate" }
        .flat_map do |fact|
          candidate = fact["value"] || {}
          start_year = candidate["year_start"]
          end_year = candidate["year_end"] || start_year
          years = start_year && end_year ? (start_year.to_i..end_year.to_i).to_a : [ start_year ].compact
          years.map { |year| { "year" => year, "make" => candidate["make"], "model" => candidate["model"] }.compact }
        end
    end

    def attributes_for(record, product)
      from_product = Array(product["attributes"]).filter_map do |attribute|
        next unless attribute["name"].present? && attribute["value"].present?

        { "class" => attribute["attribute_class"], "attribute" => attribute["name"],
          "unit" => attribute["unit"], "value" => attribute["value"] }.compact
      end
      from_facts = record.facts.filter_map do |fact|
        next unless fact["type"] == "source_product_attribute" && fact["confidence"] == "supplier_asserted"

        attribute = fact["value"] || {}
        next if attribute["name"].blank? || attribute["value"].blank?

        { "class" => attribute["attribute_class"], "attribute" => attribute["name"],
          "unit" => attribute["unit"], "value" => attribute["value"] }.compact
      end
      (from_product + from_facts).uniq
    end

    def taxonomy_node(raw, fallback_name)
      return raw.to_h.deep_stringify_keys if raw.present? && raw.respond_to?(:to_h)
      return if fallback_name.blank?

      { "name" => fallback_name, "translations" => { "es" => fallback_name } }
    end

    def years_range(applications)
      years = applications.filter_map { |application| application["year"] }.uniq.sort
      [ years.min, years.max ] if years.any?
    end
  end
end
