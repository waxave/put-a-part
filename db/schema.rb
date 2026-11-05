# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_05_000110) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attribute_definitions", force: :cascade do |t|
    t.string "attribute_class", default: "", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "default_unit"
    t.string "external_system"
    t.string "external_id"
    t.string "source_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "catalog_key"
    t.index ["attribute_class", "normalized_name"], name: "index_attribute_definitions_on_class_and_name", unique: true
    t.index ["catalog_key"], name: "index_attribute_definitions_on_catalog_key", unique: true
    t.index ["external_system", "external_id"], name: "index_attribute_definitions_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
  end

  create_table "automotive_brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "external_system"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_system", "external_id"], name: "index_automotive_brands_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["normalized_name"], name: "index_automotive_brands_on_normalized_name", unique: true
  end

  create_table "catalog_assertions", force: :cascade do |t|
    t.bigint "processing_record_id", null: false
    t.bigint "catalog_part_id"
    t.bigint "catalog_observation_id"
    t.bigint "vehicle_configuration_id"
    t.bigint "related_catalog_part_id"
    t.string "assertion_key", null: false
    t.string "assertion_type", null: false
    t.string "status", default: "candidate", null: false
    t.string "source_key", null: false
    t.integer "claim_index"
    t.text "raw_value"
    t.jsonb "value", default: {}, null: false
    t.jsonb "reviewed_value"
    t.text "evidence_url"
    t.string "parser_id"
    t.string "ruleset_version"
    t.datetime "retrieved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_candidate_id"
    t.bigint "attribute_definition_id"
    t.index ["attribute_definition_id"], name: "index_catalog_assertions_on_attribute_definition_id"
    t.index ["catalog_observation_id"], name: "index_catalog_assertions_on_catalog_observation_id"
    t.index ["catalog_part_id", "assertion_type", "status"], name: "index_catalog_assertions_for_part_resolution"
    t.index ["catalog_part_id"], name: "index_catalog_assertions_on_catalog_part_id"
    t.index ["processing_record_id", "assertion_key"], name: "index_catalog_assertions_on_record_and_key", unique: true
    t.index ["processing_record_id"], name: "index_catalog_assertions_on_processing_record_id"
    t.index ["related_catalog_part_id"], name: "index_catalog_assertions_on_related_catalog_part_id"
    t.index ["source_key", "status", "assertion_type"], name: "index_catalog_assertions_for_source_review"
    t.index ["vehicle_candidate_id"], name: "index_catalog_assertions_on_vehicle_candidate_id"
    t.index ["vehicle_configuration_id"], name: "index_catalog_assertions_on_vehicle_configuration_id"
    t.check_constraint "status::text = ANY (ARRAY['candidate'::character varying, 'reviewed'::character varying, 'verified'::character varying, 'conflict'::character varying, 'rejected'::character varying]::text[])", name: "catalog_assertions_status_check"
  end

  create_table "catalog_observations", force: :cascade do |t|
    t.bigint "processing_record_id", null: false
    t.string "source_key", null: false
    t.string "source_url", null: false
    t.string "source_sku", null: false
    t.string "status", default: "candidate", null: false
    t.jsonb "claims", default: [], null: false
    t.string "content_sha256"
    t.datetime "retrieved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processing_record_id", "source_key", "source_url"], name: "index_catalog_observations_on_record_and_source", unique: true
    t.index ["processing_record_id"], name: "index_catalog_observations_on_processing_record_id"
  end

  create_table "catalog_parts", force: :cascade do |t|
    t.bigint "automotive_brand_id", null: false
    t.string "part_number", null: false
    t.string "part_number_key", null: false
    t.string "product_category"
    t.text "source_description"
    t.string "external_system"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "catalog_product_category_id"
    t.index ["automotive_brand_id", "part_number_key"], name: "index_catalog_parts_on_brand_and_exact_variant", unique: true
    t.index ["automotive_brand_id"], name: "index_catalog_parts_on_automotive_brand_id"
    t.index ["catalog_product_category_id"], name: "index_catalog_parts_on_catalog_product_category_id"
    t.index ["external_system", "external_id"], name: "index_catalog_parts_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
  end

  create_table "catalog_product_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "external_system"
    t.string "external_id"
    t.string "source_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_system", "external_id"], name: "index_product_categories_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["normalized_name"], name: "index_catalog_product_categories_on_normalized_name", unique: true
  end

  create_table "enrichment_requests", force: :cascade do |t|
    t.bigint "processing_record_id", null: false
    t.string "source_key", null: false
    t.string "status", default: "queued", null: false
    t.integer "attempt_count", default: 0, null: false
    t.string "last_error_code"
    t.text "last_error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processing_record_id", "source_key"], name: "index_enrichment_requests_on_record_and_source", unique: true
    t.index ["processing_record_id"], name: "index_enrichment_requests_on_processing_record_id"
  end

  create_table "knowledge_release_assertions", force: :cascade do |t|
    t.uuid "knowledge_release_id", null: false
    t.bigint "catalog_assertion_id", null: false
    t.jsonb "entry_snapshot", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_assertion_id"], name: "index_knowledge_release_assertions_on_catalog_assertion_id"
    t.index ["knowledge_release_id", "catalog_assertion_id"], name: "index_release_assertions_on_release_and_assertion", unique: true
    t.index ["knowledge_release_id"], name: "index_knowledge_release_assertions_on_knowledge_release_id"
  end

  create_table "knowledge_releases", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "entries", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "part_identifiers", force: :cascade do |t|
    t.bigint "catalog_part_id", null: false
    t.bigint "catalog_observation_id"
    t.string "identifier_type", null: false
    t.string "identifier_value", null: false
    t.string "normalized_identifier", null: false
    t.string "source_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_observation_id"], name: "index_part_identifiers_on_catalog_observation_id"
    t.index ["catalog_part_id", "identifier_type", "normalized_identifier"], name: "index_part_identifiers_on_part_type_and_value", unique: true
    t.index ["catalog_part_id"], name: "index_part_identifiers_on_catalog_part_id"
  end

  create_table "processing_issues", force: :cascade do |t|
    t.uuid "processing_run_id", null: false
    t.bigint "processing_record_id"
    t.string "stage", null: false
    t.string "severity", null: false
    t.string "code", null: false
    t.text "message", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processing_record_id", "stage", "code"], name: "index_processing_issues_on_record_stage_code", unique: true, where: "(processing_record_id IS NOT NULL)"
    t.index ["processing_record_id"], name: "index_processing_issues_on_processing_record_id"
    t.index ["processing_run_id"], name: "index_processing_issues_on_processing_run_id"
  end

  create_table "processing_records", force: :cascade do |t|
    t.uuid "processing_run_id", null: false
    t.string "source_sheet", null: false
    t.integer "source_row", null: false
    t.string "source_sku"
    t.string "status", default: "pending", null: false
    t.jsonb "normalized_product", default: {}, null: false
    t.jsonb "facts", default: [], null: false
    t.jsonb "unresolved", default: [], null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processing_run_id", "source_sheet", "source_row"], name: "index_processing_records_on_run_and_source", unique: true
    t.index ["processing_run_id"], name: "index_processing_records_on_processing_run_id"
  end

  create_table "processing_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "queued", null: false
    t.string "stage", default: "queued", null: false
    t.string "format_key"
    t.string "format_version"
    t.string "ruleset_version"
    t.string "knowledge_release_id"
    t.string "export_schema_version"
    t.string "input_sha256"
    t.integer "total_records", default: 0, null: false
    t.integer "processed_records", default: 0, null: false
    t.integer "successful_records", default: 0, null: false
    t.integer "warning_records", default: 0, null: false
    t.integer "failed_records", default: 0, null: false
    t.integer "progress_percent", default: 0, null: false
    t.integer "attempt_count", default: 0, null: false
    t.string "last_error_code"
    t.text "last_error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attribute_catalog_version"
    t.index ["status", "created_at"], name: "index_processing_runs_on_status_and_created_at"
  end

  create_table "reviewed_applications", force: :cascade do |t|
    t.bigint "catalog_observation_id", null: false
    t.integer "claim_index", null: false
    t.string "manufacturer", null: false
    t.string "model", null: false
    t.integer "year", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_observation_id", "claim_index"], name: "index_reviewed_applications_on_observation_and_claim", unique: true
    t.index ["catalog_observation_id"], name: "index_reviewed_applications_on_catalog_observation_id"
  end

  create_table "reviewed_attributes", force: :cascade do |t|
    t.bigint "catalog_observation_id", null: false
    t.integer "claim_index", null: false
    t.string "attribute_class", null: false
    t.string "name", null: false
    t.string "unit"
    t.text "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_observation_id", "claim_index"], name: "index_reviewed_attributes_on_observation_and_claim", unique: true
    t.index ["catalog_observation_id"], name: "index_reviewed_attributes_on_catalog_observation_id"
  end

  create_table "reviewed_catalog_fields", force: :cascade do |t|
    t.bigint "catalog_observation_id", null: false
    t.integer "claim_index", null: false
    t.string "field", null: false
    t.text "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_observation_id", "claim_index", "field"], name: "index_reviewed_catalog_fields_on_claim_and_field", unique: true
    t.index ["catalog_observation_id"], name: "index_reviewed_catalog_fields_on_catalog_observation_id"
  end

  create_table "reviewed_interchanges", force: :cascade do |t|
    t.bigint "catalog_observation_id", null: false
    t.integer "claim_index", null: false
    t.string "reference", null: false
    t.string "brand", null: false
    t.text "evidence_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["catalog_observation_id", "claim_index"], name: "index_reviewed_interchanges_on_observation_and_claim", unique: true
    t.index ["catalog_observation_id"], name: "index_reviewed_interchanges_on_catalog_observation_id"
  end

  create_table "vehicle_aliases", force: :cascade do |t|
    t.bigint "vehicle_make_id"
    t.bigint "vehicle_model_id"
    t.bigint "vehicle_configuration_id"
    t.string "alias_text", null: false
    t.string "normalized_alias", null: false
    t.string "source_key", null: false
    t.string "review_status", default: "candidate", null: false
    t.text "evidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vehicle_configuration_id", "normalized_alias"], name: "index_vehicle_aliases_on_configuration_and_alias", unique: true, where: "(vehicle_configuration_id IS NOT NULL)"
    t.index ["vehicle_configuration_id"], name: "index_vehicle_aliases_on_vehicle_configuration_id"
    t.index ["vehicle_make_id", "normalized_alias"], name: "index_vehicle_aliases_on_make_and_normalized_alias", unique: true, where: "(vehicle_make_id IS NOT NULL)"
    t.index ["vehicle_make_id"], name: "index_vehicle_aliases_on_vehicle_make_id"
    t.index ["vehicle_model_id", "normalized_alias"], name: "index_vehicle_aliases_on_model_and_normalized_alias", unique: true, where: "(vehicle_model_id IS NOT NULL)"
    t.index ["vehicle_model_id"], name: "index_vehicle_aliases_on_vehicle_model_id"
    t.check_constraint "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id) = 1", name: "vehicle_aliases_one_entity_check"
    t.check_constraint "review_status::text = ANY (ARRAY['candidate'::character varying, 'accepted'::character varying, 'rejected'::character varying]::text[])", name: "vehicle_aliases_review_status_check"
  end

  create_table "vehicle_candidate_matches", force: :cascade do |t|
    t.bigint "vehicle_candidate_id", null: false
    t.bigint "vehicle_configuration_id", null: false
    t.string "external_system", null: false
    t.string "source_version", null: false
    t.string "match_reason", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_system", "source_version"], name: "index_vehicle_candidate_matches_on_reference_version"
    t.index ["vehicle_candidate_id", "vehicle_configuration_id", "external_system", "source_version"], name: "index_vehicle_candidate_matches_on_candidate_config_version", unique: true
    t.index ["vehicle_candidate_id"], name: "index_vehicle_candidate_matches_on_vehicle_candidate_id"
    t.index ["vehicle_configuration_id"], name: "index_vehicle_candidate_matches_on_vehicle_configuration_id"
  end

  create_table "vehicle_candidates", force: :cascade do |t|
    t.bigint "processing_record_id", null: false
    t.bigint "catalog_part_id"
    t.bigint "catalog_observation_id"
    t.bigint "vehicle_configuration_id"
    t.string "assertion_key", null: false
    t.string "source_key", null: false
    t.integer "claim_index"
    t.string "make_candidate"
    t.string "model_candidate"
    t.integer "model_year_start"
    t.integer "model_year_end"
    t.string "engine_code_candidate"
    t.jsonb "qualifiers", default: {}, null: false
    t.text "raw_text", null: false
    t.string "parse_status", default: "candidate", null: false
    t.string "parser_id"
    t.string "ruleset_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "resolution_status", default: "unresolved", null: false
    t.index ["catalog_observation_id"], name: "index_vehicle_candidates_on_catalog_observation_id"
    t.index ["catalog_part_id"], name: "index_vehicle_candidates_on_catalog_part_id"
    t.index ["make_candidate", "model_candidate", "model_year_start", "model_year_end"], name: "index_vehicle_candidates_for_matching"
    t.index ["processing_record_id", "assertion_key"], name: "index_vehicle_candidates_on_record_and_key", unique: true
    t.index ["processing_record_id"], name: "index_vehicle_candidates_on_processing_record_id"
    t.index ["source_key", "parse_status"], name: "index_vehicle_candidates_for_review"
    t.index ["vehicle_configuration_id"], name: "index_vehicle_candidates_on_vehicle_configuration_id"
    t.check_constraint "parse_status::text = ANY (ARRAY['candidate'::character varying, 'interpreted'::character varying, 'unresolved'::character varying, 'reviewed'::character varying, 'conflict'::character varying, 'rejected'::character varying]::text[])", name: "vehicle_candidates_parse_status_check"
    t.check_constraint "resolution_status::text = ANY (ARRAY['unresolved'::character varying, 'matched'::character varying, 'partial'::character varying, 'ambiguous'::character varying, 'no_match'::character varying]::text[])", name: "vehicle_candidates_resolution_status_check"
  end

  create_table "vehicle_configurations", force: :cascade do |t|
    t.bigint "vehicle_model_id", null: false
    t.integer "model_year", null: false
    t.string "submodel"
    t.string "engine_code"
    t.decimal "displacement_liters", precision: 5, scale: 2
    t.integer "cylinder_count"
    t.jsonb "configuration", default: {}, null: false
    t.string "external_system"
    t.string "external_id"
    t.string "source_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_system", "external_id"], name: "index_vehicle_configurations_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["vehicle_model_id", "model_year"], name: "idx_on_vehicle_model_id_model_year_b9b4f62ee3"
    t.index ["vehicle_model_id"], name: "index_vehicle_configurations_on_vehicle_model_id"
    t.check_constraint "model_year >= 1886 AND model_year <= 2100", name: "vehicle_configurations_model_year_range"
  end

  create_table "vehicle_engine_variants", force: :cascade do |t|
    t.bigint "vehicle_generation_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "fuel_type"
    t.integer "cylinder_count"
    t.integer "displacement_cc"
    t.decimal "power_hp", precision: 8, scale: 2
    t.decimal "torque_nm", precision: 8, scale: 2
    t.string "transmission"
    t.string "drivetrain"
    t.jsonb "specifications", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vehicle_generation_id", "normalized_name"], name: "index_vehicle_engines_on_generation_and_name", unique: true
    t.index ["vehicle_generation_id"], name: "index_vehicle_engine_variants_on_vehicle_generation_id"
  end

  create_table "vehicle_generations", force: :cascade do |t|
    t.bigint "vehicle_model_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.integer "year_start"
    t.integer "year_end"
    t.string "body_type"
    t.jsonb "source_attributes", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vehicle_model_id", "normalized_name"], name: "index_vehicle_generations_on_model_and_name", unique: true
    t.index ["vehicle_model_id"], name: "index_vehicle_generations_on_vehicle_model_id"
    t.check_constraint "(year_start IS NULL OR year_start >= 1886 AND year_start <= 2100) AND (year_end IS NULL OR year_end >= 1886 AND year_end <= 2100) AND (year_start IS NULL OR year_end IS NULL OR year_end >= year_start)", name: "vehicle_generations_valid_year_range"
  end

  create_table "vehicle_makes", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "external_system"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_system", "external_id"], name: "index_vehicle_makes_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["normalized_name"], name: "index_vehicle_makes_on_normalized_name", unique: true
  end

  create_table "vehicle_models", force: :cascade do |t|
    t.bigint "vehicle_make_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "external_system"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_kind"
    t.index "vehicle_make_id, normalized_name, COALESCE(vehicle_kind, 'unspecified'::character varying)", name: "index_vehicle_models_on_make_kind_and_name", unique: true
    t.index ["external_system", "external_id"], name: "index_vehicle_models_on_external_identity", unique: true, where: "((external_system IS NOT NULL) AND (external_id IS NOT NULL))"
    t.index ["vehicle_make_id"], name: "index_vehicle_models_on_vehicle_make_id"
  end

  create_table "vehicle_reference_datasets", force: :cascade do |t|
    t.string "source_key", null: false
    t.string "source_version", null: false
    t.string "artifact_name", null: false
    t.string "sha256", null: false
    t.string "license_identifier"
    t.text "attribution"
    t.string "schema_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_key", "source_version", "sha256"], name: "index_vehicle_reference_datasets_on_source_version_checksum", unique: true
  end

  create_table "vehicle_reference_imports", force: :cascade do |t|
    t.bigint "vehicle_reference_dataset_id", null: false
    t.string "status", default: "pending", null: false
    t.boolean "dry_run", default: true, null: false
    t.string "normalizer_version", null: false
    t.jsonb "counts", default: {}, null: false
    t.text "error_summary"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vehicle_reference_dataset_id", "created_at"], name: "index_vehicle_reference_imports_on_dataset_and_created"
    t.index ["vehicle_reference_dataset_id"], name: "idx_on_vehicle_reference_dataset_id_20878f962e"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'running'::character varying, 'validated'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "vehicle_reference_imports_status_check"
  end

  create_table "vehicle_reference_records", force: :cascade do |t|
    t.bigint "vehicle_reference_dataset_id", null: false
    t.bigint "vehicle_make_id"
    t.bigint "vehicle_model_id"
    t.bigint "vehicle_configuration_id"
    t.string "record_type", null: false
    t.string "source_record_id", null: false
    t.string "source_parent_id"
    t.string "resolution_status", default: "unresolved", null: false
    t.string "normalizer_version", null: false
    t.string "content_sha256", null: false
    t.jsonb "raw_record", default: {}, null: false
    t.jsonb "normalized_record", default: {}, null: false
    t.jsonb "validation_issues", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_reference_import_id"
    t.bigint "vehicle_generation_id"
    t.bigint "vehicle_engine_variant_id"
    t.index ["content_sha256"], name: "index_vehicle_reference_records_on_content_sha256"
    t.index ["record_type", "resolution_status"], name: "index_vehicle_reference_records_on_type_and_resolution"
    t.index ["vehicle_configuration_id"], name: "index_vehicle_reference_records_on_vehicle_configuration_id"
    t.index ["vehicle_engine_variant_id"], name: "index_vehicle_reference_records_on_vehicle_engine_variant_id"
    t.index ["vehicle_generation_id"], name: "index_vehicle_reference_records_on_vehicle_generation_id"
    t.index ["vehicle_make_id"], name: "index_vehicle_reference_records_on_vehicle_make_id"
    t.index ["vehicle_model_id"], name: "index_vehicle_reference_records_on_vehicle_model_id"
    t.index ["vehicle_reference_dataset_id", "source_record_id"], name: "index_vehicle_reference_records_on_dataset_and_source_id", unique: true
    t.index ["vehicle_reference_dataset_id"], name: "idx_on_vehicle_reference_dataset_id_7366fc9ff5"
    t.index ["vehicle_reference_import_id"], name: "index_vehicle_reference_records_on_vehicle_reference_import_id"
    t.check_constraint "resolution_status::text = ANY (ARRAY['unresolved'::character varying, 'matched'::character varying, 'partial'::character varying, 'ambiguous'::character varying, 'conflict'::character varying, 'rejected'::character varying]::text[])", name: "vehicle_reference_records_resolution_check"
  end

  create_table "vehicle_search_entries", force: :cascade do |t|
    t.bigint "vehicle_make_id"
    t.bigint "vehicle_model_id"
    t.bigint "vehicle_configuration_id"
    t.string "entry_type", null: false
    t.text "display_text", null: false
    t.text "normalized_text", null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('simple'::regconfig, COALESCE(display_text, ''::text))", stored: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_generation_id"
    t.bigint "vehicle_engine_variant_id"
    t.index ["normalized_text"], name: "index_vehicle_search_entries_on_normalized_text"
    t.index ["search_vector"], name: "index_vehicle_search_entries_on_search_vector", using: :gin
    t.index ["vehicle_configuration_id"], name: "index_vehicle_search_entries_on_vehicle_configuration_id"
    t.index ["vehicle_engine_variant_id"], name: "index_vehicle_search_entries_on_vehicle_engine_variant_id"
    t.index ["vehicle_generation_id"], name: "index_vehicle_search_entries_on_vehicle_generation_id"
    t.index ["vehicle_make_id"], name: "index_vehicle_search_entries_on_vehicle_make_id"
    t.index ["vehicle_model_id"], name: "index_vehicle_search_entries_on_vehicle_model_id"
    t.check_constraint "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id, vehicle_generation_id, vehicle_engine_variant_id) = 1", name: "vehicle_search_entries_one_entity_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "catalog_assertions", "attribute_definitions"
  add_foreign_key "catalog_assertions", "catalog_observations"
  add_foreign_key "catalog_assertions", "catalog_parts"
  add_foreign_key "catalog_assertions", "catalog_parts", column: "related_catalog_part_id"
  add_foreign_key "catalog_assertions", "processing_records"
  add_foreign_key "catalog_assertions", "vehicle_candidates"
  add_foreign_key "catalog_assertions", "vehicle_configurations"
  add_foreign_key "catalog_observations", "processing_records"
  add_foreign_key "catalog_parts", "automotive_brands"
  add_foreign_key "catalog_parts", "catalog_product_categories"
  add_foreign_key "enrichment_requests", "processing_records"
  add_foreign_key "knowledge_release_assertions", "catalog_assertions"
  add_foreign_key "knowledge_release_assertions", "knowledge_releases"
  add_foreign_key "part_identifiers", "catalog_observations"
  add_foreign_key "part_identifiers", "catalog_parts"
  add_foreign_key "processing_issues", "processing_records"
  add_foreign_key "processing_issues", "processing_runs"
  add_foreign_key "processing_records", "processing_runs"
  add_foreign_key "reviewed_applications", "catalog_observations"
  add_foreign_key "reviewed_attributes", "catalog_observations"
  add_foreign_key "reviewed_catalog_fields", "catalog_observations"
  add_foreign_key "reviewed_interchanges", "catalog_observations"
  add_foreign_key "vehicle_aliases", "vehicle_configurations"
  add_foreign_key "vehicle_aliases", "vehicle_makes"
  add_foreign_key "vehicle_aliases", "vehicle_models"
  add_foreign_key "vehicle_candidate_matches", "vehicle_candidates"
  add_foreign_key "vehicle_candidate_matches", "vehicle_configurations"
  add_foreign_key "vehicle_candidates", "catalog_observations"
  add_foreign_key "vehicle_candidates", "catalog_parts"
  add_foreign_key "vehicle_candidates", "processing_records"
  add_foreign_key "vehicle_candidates", "vehicle_configurations"
  add_foreign_key "vehicle_configurations", "vehicle_models"
  add_foreign_key "vehicle_engine_variants", "vehicle_generations"
  add_foreign_key "vehicle_generations", "vehicle_models"
  add_foreign_key "vehicle_models", "vehicle_makes"
  add_foreign_key "vehicle_reference_imports", "vehicle_reference_datasets"
  add_foreign_key "vehicle_reference_records", "vehicle_configurations"
  add_foreign_key "vehicle_reference_records", "vehicle_engine_variants"
  add_foreign_key "vehicle_reference_records", "vehicle_generations"
  add_foreign_key "vehicle_reference_records", "vehicle_makes"
  add_foreign_key "vehicle_reference_records", "vehicle_models"
  add_foreign_key "vehicle_reference_records", "vehicle_reference_datasets"
  add_foreign_key "vehicle_reference_records", "vehicle_reference_imports"
  add_foreign_key "vehicle_search_entries", "vehicle_configurations"
  add_foreign_key "vehicle_search_entries", "vehicle_engine_variants"
  add_foreign_key "vehicle_search_entries", "vehicle_generations"
  add_foreign_key "vehicle_search_entries", "vehicle_makes"
  add_foreign_key "vehicle_search_entries", "vehicle_models"
end
