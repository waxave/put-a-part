module Etl
  ExecutionContext = Data.define(:format_key, :format_version, :ruleset_version, :knowledge_release_id, :export_schema_version,
    :attribute_catalog_version)
end
