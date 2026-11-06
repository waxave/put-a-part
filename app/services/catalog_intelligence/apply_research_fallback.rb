module CatalogIntelligence
  class ApplyResearchFallback
    include ServiceCall

    def call(run)
      client = Autofacts::Client.new
      run.processing_records.find_each do |record|
        request = record.enrichment_requests.find_by(source_key: QueueAutofactsResearch::SOURCE_KEY)
        product = record.normalized_product.deep_dup
        unless request&.status == "completed"
          product["applications"] = (Array(product["applications"]) + extracted_applications(record)).uniq
        end
        product["interchanges"] = (Array(product["interchanges"]) + extracted_interchanges(record, product["interchange_origin"])).uniq
        category = category_from_taxonomy(client, product, request)
        if category
          fields = product.fetch("catalog_fields", {}).deep_dup
          fields["system"] = { "value" => category[:category], "source" => "autofacts_taxonomy" }
          fields["subsystem"] = { "value" => category[:subcategory], "source" => "autofacts_taxonomy" }
          product["catalog_fields"] = fields
          product["subcategory"] ||= category[:subcategory]
        end
        kind_labels = Array(product["applications"]).flat_map { |application| local_vehicle_kinds(application) }
        fields = product.fetch("catalog_fields", {}).deep_dup
        if kind_labels.any? && kind_labels.none?(&:nil?) && kind_labels.uniq.one?
          fields["category"] = { "value" => kind_labels.first, "source" => "local_vehicle_catalog" }
        end
        product["catalog_fields"] = fields
        product["extraction_fallback"] = BuildExtractedPartResult.call(record, product: product,
          taxonomy: category, autofacts_result: request&.result_data&.dig("autofacts_result"))
        record.update!(normalized_product: product)
      end
    ensure
      client&.close
    end

    private

    def extracted_applications(record)
      vehicle_facts = record.facts.select { |fact| fact["type"] == "vehicle_candidate" && fact["confidence"] == "candidate" }
      vehicle_facts.flat_map do |fact|
        value = fact["value"] || {}
        start_year = value["year_start"]
        end_year = value["year_end"] || start_year
        years = start_year && end_year ? (start_year.to_i..end_year.to_i).to_a : [ start_year ].compact
        years.map do |year|
          { "manufacturer" => value["make"], "model" => value["model"], "year" => year,
            "evidence_status" => "candidate" }.compact
        end
      end
    end

    def extracted_interchanges(record, origin)
      record.facts.select { |fact| fact["type"] == "reference_candidate" && fact["confidence"] == "candidate" }
        .map { |fact| { "interchange_reference" => fact["value"], "origin" => origin, "source_key" => "extracted_candidate", "evidence_status" => "candidate" }.compact }
    end

    def category_from_taxonomy(client, product, request)
      result_taxonomy = [ request&.result_data&.dig("subcategory"), request&.result_data&.dig("category") ]
      terms = result_taxonomy.map { |node| taxonomy_name(node) } + [ product["subcategory"], product["category"], product["description"] ]
      terms.compact_blank.each do |term|
        matches = client.search_subcategories(term, locale: "es")
        next if matches.empty?

        subcategory = matches.first
        category = client.categories(locale: "es").find { |item| item.slug == subcategory.category }
        next unless category

        return { category: taxonomy_name(category), subcategory: taxonomy_name(subcategory) }
      end

      subcategory = taxonomy_name(result_taxonomy.first)
      category = taxonomy_name(result_taxonomy.last)
      return { category: category, subcategory: subcategory } if category.present? && subcategory.present?

      nil
    end

    def taxonomy_name(value)
      return if value.blank?
      return value.to_s unless value.respond_to?(:to_h)

      data = value.to_h.deep_stringify_keys
      translations = data["translations"] || {}
      translations["es"].presence || translations["es-MX"].presence || data["name"].presence
    end

    def local_vehicle_kinds(application)
      make_name = application["manufacturer"].to_s
      model_name = application["model"].to_s
      return [] if make_name.blank? || model_name.blank?

      make = VehicleMake.find_by(normalized_name: normalize_vehicle_name(make_name))
      return [] unless make

      phrase = normalize_vehicle_name(model_name)
      terms = phrase_terms(phrase)
      models = make.vehicle_models.where(normalized_name: terms).pluck(:id, :name, :normalized_name).filter_map do |id, name, normalized_name|
        pattern = /(?<![[:alnum:]])#{Regexp.escape(normalize_vehicle_name(normalized_name))}(?![[:alnum:]])/
        match = pattern.match(phrase)
        [ match.begin(0), match.end(0), id, name ] if match
      end.sort_by { |start, finish, _id, _name| [ start, -(finish - start) ] }
      selected = []
      models.each do |hit|
        selected << hit unless selected.any? { |existing| hit[0] < existing[1] && existing[0] < hit[1] }
      end
      models = VehicleModel.where(id: selected.map { |hit| hit[2] })
      models.map { |model| Automotive::Domain::VehicleKindLabels.call(model.vehicle_kind) }
    end

    def normalize_vehicle_name(value)
      Automotive::Knowledge::NormalizeVehicleText.call(value)
    end

    def phrase_terms(value)
      words = value.split
      (1..[ words.length, 6 ].min).flat_map do |length|
        (0..words.length - length).map { |start| words[start, length].join(" ") }
      end.uniq
    end
  end
end
