require "digest"
require "json"

module CatalogIntelligence
  class AutofactsResearch
    include ServiceCall

    SOURCE_KEY = QueueAutofactsResearch::SOURCE_KEY

    def self.call(request, phase: "part", client_factory: nil)
      new(client_factory: client_factory).call(request, phase: phase)
    end

    def initialize(client_factory: nil, client: nil)
      @client_factory = client_factory || -> { client || build_client }
    end

    def call(request, phase: "part")
      record = request.processing_record
      product = record.normalized_product
      sku = product["sku"].presence || record.source_sku
      source_brand = product["brand"].to_s
      client = @client_factory.call

      Rails.logger.info("Autofacts lookup started run_id=#{record.processing_run_id} record_id=#{record.id} sku=#{sku.inspect} brand=#{source_brand.inspect} gem_version=#{Autofacts::VERSION}")
      if phase == "part"
        begin
          part = client.part(sku, brand: source_brand)
          if part && exact_part_number?(part.part_number, sku) && same_brand?(source_brand, part.brand, part.brand_slug)
            persist_match(request, sku, part, client: client)
            log_outcome(request, sku, 1, 1)
            return :completed
          end
        rescue Autofacts::RequestError
          raise
        rescue Autofacts::Error => error
          Rails.logger.info("Autofacts direct part lookup unavailable request_id=#{request.id} error=#{error.class}: #{error.message}")
        end
        schedule_find(request, sku)
        return :waiting_for_fallback
      end

      search = client.find(sku, page: 1)
      number_matches = Array(search.parts).select { |candidate| same_clean_part_number?(candidate.part_number, sku) }
      brand_matches = number_matches.select { |candidate| same_brand?(source_brand, candidate.brand, candidate.brand_slug) }

      if brand_matches.one? && exact_part_number?(brand_matches.first.part_number, sku)
        detail = client.part(brand_matches.first.part_number, brand: brand_matches.first.brand)
        if detail && exact_part_number?(detail.part_number, sku) && same_brand?(source_brand, detail.brand, detail.brand_slug)
          persist_match(request, sku, detail, client: client)
        else
          complete_ambiguous(request, sku, [ brand_matches.first ], reason: "Part detail did not confirm the exact requested part and brand.")
        end
      elsif brand_matches.empty? && number_matches.empty? && !search.next_page?
        finish(request, sku, "not_found", "no_search_results", "Autofacts returned no exact part number and brand match.",
          "reported_result_count" => search.result_count, "parsed_result_count" => Array(search.parts).length)
      else
        complete_ambiguous(request, sku, brand_matches.presence || number_matches.presence || Array(search.parts),
          reason: "No unique exact part number and brand match was established.")
      end
      log_outcome(request, sku, brand_matches.length, number_matches.length)
    rescue Autofacts::RequestError => error
      Rails.logger.error("Autofacts request failed run_id=#{record&.processing_run_id} record_id=#{record&.id} sku=#{sku.inspect} brand=#{source_brand.inspect} error=#{error.class}: #{error.message}")
      raise
    rescue Autofacts::ParseError, Autofacts::Error => error
      if phase == "part"
        schedule_find(request, sku)
        Rails.logger.warn("Autofacts direct part lookup failed; scheduling fallback request_id=#{request.id} error=#{error.class}: #{error.message}")
        return :waiting_for_fallback
      end
      finish(request, sku, "failed", error.class.name, error.message)
      Rails.logger.error("Autofacts lookup failed run_id=#{record&.processing_run_id} record_id=#{record&.id} sku=#{sku.inspect} brand=#{source_brand.inspect} error=#{error.class}: #{error.message}")
    ensure
      client&.close
    end

    private

    def build_client
      Autofacts::Client.new
    end

    def schedule_find(request, sku)
      request.update!(status: "queued", enqueued_at: Time.current, finished_at: nil,
        result_data: { "query" => sku, "reason_code" => "direct_part_unavailable",
          "reason" => "Direct part lookup returned no usable result; fallback search will run after a 30-second delay." })
    end

    def normalize_brand(value)
      value.to_s.downcase.gsub(/[^[:alnum:]]+/, "")
    end

    def same_brand?(source_brand, result_brand, result_slug)
      source = normalize_brand(source_brand)
      source.present? && [ result_brand, result_slug ].any? { |name| normalize_brand(name) == source }
    end

    def clean_part_number(value)
      Autofacts::PartNumber.clean(value).downcase.gsub(/\s+/, "")
    end

    def same_clean_part_number?(left, right)
      clean_part_number(left) == clean_part_number(right)
    end

    def exact_part_number?(left, right)
      left.to_s.strip.gsub(/\s+/, " ").casecmp?(right.to_s.strip.gsub(/\s+/, " "))
    end

    def complete_ambiguous(request, sku, candidates, reason:)
      summarized = Array(candidates).first(20).map { |candidate| candidate_summary(candidate) }
      finish(request, sku, "ambiguous", "ambiguous_match", reason, "candidates" => summarized)
    end

    def finish(request, sku, status, reason_code, reason, details = {})
      request.update!(status: status, result_data: { "query" => sku, "reason_code" => reason_code, "reason" => reason }.merge(details),
        finished_at: Time.current)
    end

    def log_outcome(request, sku, brand_matches, number_matches)
      Rails.logger.info("Autofacts lookup finished request_id=#{request.id} sku=#{sku.inspect} status=#{request.status} part_number_candidates=#{number_matches} exact_brand_candidates=#{brand_matches} reason=#{request.result_data['reason_code'].inspect}")
    end

    def candidate_summary(candidate)
      {
        "part_number" => candidate.part_number,
        "brand" => candidate.brand,
        "brand_slug" => candidate.brand_slug,
        "description" => candidate.description,
        "url" => candidate.url,
        "category" => candidate.category,
        "subcategory" => candidate.subcategory
      }.compact
    end

    def persist_match(request, sku, part, client:)
      claims = claims_for(part)
      source_url = part.url
      raise Autofacts::Error, "Autofacts returned a part without a source URL" if source_url.blank?

      observation = request.processing_record.catalog_observations.find_or_initialize_by(source_key: SOURCE_KEY, source_url: source_url)
      observation.assign_attributes(source_sku: sku, status: "candidate", claims: claims,
        content_sha256: Digest::SHA256.hexdigest(JSON.generate(claims)), retrieved_at: Time.current)
      observation.save!
      PersistObservation.call(observation)

      persist_part_fields(request.processing_record, part, client: client)

      request.update!(status: "completed", finished_at: Time.current,
        result_data: candidate_summary(part).merge("query" => sku, "reason_code" => "match_found", "reason" => "Exact part number and brand candidate found.",
          "attributes" => claims.count { |claim| claim["type"] == "source_field" },
          "applications" => claims.count { |claim| claim["type"] == "application_candidate" },
          "observation_id" => observation.id, "autofacts_result" => part.to_h.deep_stringify_keys))
    end

    def persist_part_fields(record, part, client:)
      country_alpha3 = client.countries.index_by { |country| country.code.to_s.upcase }
      product = record.normalized_product.deep_dup
      product["applications"] = Array(part.applications).map do |application|
        fields = application.to_h.stringify_keys
        { "manufacturer" => fields["make"], "model" => fields["model"], "year" => fields["year"],
          "qualifiers" => { "engine" => fields["engine"],
            "market" => fields["country_alpha3"].presence || country_alpha3[fields["country_code"].to_s.upcase]&.alpha_3 }.compact }.compact
      end
      product["attributes"] = Array(part.attributes).map do |attribute|
        fields = attribute.to_h.stringify_keys
        { "name" => fields["attribute"], "value" => fields["value"], "unit" => fields["unit"],
          "attribute_class" => fields["class"], "candidate" => true }.compact
      end
      category = taxonomy_name(part.category)
      subcategory = taxonomy_name(part.subcategory)
      fields = product.fetch("catalog_fields", {}).deep_dup
      fields["system"] = { "value" => category, "source" => SOURCE_KEY } if category.present?
      fields["subsystem"] = { "value" => subcategory, "source" => SOURCE_KEY } if subcategory.present?
      grade = part.grade.to_s.strip
      product["interchange_origin"] = grade if grade.casecmp?("OEM") || grade.casecmp?("Aftermarket")
      product["catalog_fields"] = fields
      product["subcategory"] = subcategory if subcategory.present?
      record.update!(normalized_product: product)
    end

    def taxonomy_name(value)
      return value.to_s.presence unless value.respond_to?(:to_h)

      data = value.to_h.deep_stringify_keys
      translated = data.dig("translations", "es") || data.dig("translations", "es-MX")
      return translated if translated.present?

      data["name"].presence
    end

    def claims_for(part)
      attributes = Array(part.attributes).map do |attribute|
        fields = attribute.to_h.stringify_keys
        { "type" => "source_field", "raw_value" => fields["value"].to_s, "fields" => fields }
      end
      applications = Array(part.applications).filter_map do |application|
        fields = application.to_h.stringify_keys
        next if [ fields["year"], fields["make"], fields["model"], fields["engine"] ].all?(&:blank?)

        { "type" => "application_candidate", "raw_value" => application_summary(fields),
          "suggested_fields" => { "manufacturer" => fields["make"], "model" => fields["model"], "year" => fields["year"] }.compact,
          "qualifiers" => { "engine" => fields["engine"], "country" => fields["country_code"] }.compact }
      end.first(200)
      detail = {
        "brand" => part.brand,
        "brand_slug" => part.brand_slug,
        "part_number" => part.part_number,
        "description" => part.description,
        "category" => part.category,
        "subcategory" => part.subcategory,
        "grade" => part.grade,
        "countries" => part.countries,
        "applications_count" => part.applications_count
      }.compact

      [ { "type" => "search_result", "raw_value" => "#{part.brand} #{part.part_number}", "part" => detail } ] + attributes + applications
    end

    def application_summary(fields)
      [ fields["year"], fields["make"], fields["model"], fields["engine"] ].compact.join(" ")
    end
  end
end
