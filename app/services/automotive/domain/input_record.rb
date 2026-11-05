module Automotive
  module Domain
    InputRecord = Data.define(:source_identifier, :sku, :brand_text, :category_text, :description, :structured_fields, :metadata)
  end
end
