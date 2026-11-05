module Automotive
  class ProductExtractor < ServiceBase
    RULESET_VERSION = "1.3.0"

    def call(input)
      facts = Parsers::DescriptionParser.call(input.description).map do |fact|
        fact.stringify_keys.merge("source" => input.metadata, "parser_id" => "description", "rule_version" => RULESET_VERSION)
      end
      facts.concat(Parsers::ReferenceParser.call(input.description).map do |fact|
        fact.stringify_keys.merge("source" => input.metadata, "parser_id" => "reference", "rule_version" => RULESET_VERSION)
      end)
      facts.concat(Parsers::ProductAttributeParser.call(category: input.category_text, description: input.description).map do |fact|
        fact.stringify_keys.merge("source" => input.metadata, "parser_id" => "product_attribute", "rule_version" => RULESET_VERSION)
      end)
      if input.category_text.to_s.strip.casecmp?("ANILLOS")
        dimensions = Parsers::RingDimensionsParser.call(input.description)
        if dimensions
          facts << { "type" => "ring_dimensions", "value" => dimensions, "source" => input.metadata,
                     "parser_id" => "ring_dimensions", "rule_version" => RULESET_VERSION }
        end
      end

      product = { "sku" => input.sku, "brand" => input.brand_text, "category" => input.category_text,
                  "description" => input.description, "source_row" => input.structured_fields.fetch("source_row") }
      product["source_fields"] = input.structured_fields["source_fields"] if input.structured_fields.key?("source_fields")
      { product: product, facts: facts }
    end
  end
end
