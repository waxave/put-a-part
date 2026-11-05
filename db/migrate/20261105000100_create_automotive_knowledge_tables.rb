class CreateAutomotiveKnowledgeTables < ActiveRecord::Migration[8.1]
  def change
    create_table :automotive_brands do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :external_system
      t.string :external_id
      t.timestamps
    end
    add_index :automotive_brands, :normalized_name, unique: true
    add_index :automotive_brands, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_automotive_brands_on_external_identity"

    create_table :catalog_parts do |t|
      t.references :automotive_brand, null: false, foreign_key: true
      t.string :part_number, null: false
      t.string :part_number_key, null: false
      t.string :product_category
      t.text :source_description
      t.string :external_system
      t.string :external_id
      t.timestamps
    end
    add_index :catalog_parts, [ :automotive_brand_id, :part_number_key ], unique: true, name: "index_catalog_parts_on_brand_and_exact_variant"
    add_index :catalog_parts, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_catalog_parts_on_external_identity"

    create_table :vehicle_makes do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :external_system
      t.string :external_id
      t.timestamps
    end
    add_index :vehicle_makes, :normalized_name, unique: true
    add_index :vehicle_makes, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_vehicle_makes_on_external_identity"

    create_table :vehicle_models do |t|
      t.references :vehicle_make, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :external_system
      t.string :external_id
      t.timestamps
    end
    add_index :vehicle_models, [ :vehicle_make_id, :normalized_name ], unique: true
    add_index :vehicle_models, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_vehicle_models_on_external_identity"

    create_table :vehicle_configurations do |t|
      t.references :vehicle_model, null: false, foreign_key: true
      t.integer :model_year, null: false
      t.string :submodel
      t.string :engine_code
      t.decimal :displacement_liters, precision: 5, scale: 2
      t.integer :cylinder_count
      t.jsonb :configuration, default: {}, null: false
      t.string :external_system
      t.string :external_id
      t.string :source_version
      t.timestamps
    end
    add_index :vehicle_configurations, [ :vehicle_model_id, :model_year ]
    add_index :vehicle_configurations, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_vehicle_configurations_on_external_identity"
    add_check_constraint :vehicle_configurations, "model_year BETWEEN 1886 AND 2100", name: "vehicle_configurations_model_year_range"

    create_table :catalog_assertions do |t|
      t.references :processing_record, null: false, foreign_key: true
      t.references :catalog_part, foreign_key: true
      t.references :catalog_observation, foreign_key: true
      t.references :vehicle_configuration, foreign_key: true
      t.references :related_catalog_part, foreign_key: { to_table: :catalog_parts }
      t.string :assertion_key, null: false
      t.string :assertion_type, null: false
      t.string :status, null: false, default: "candidate"
      t.string :source_key, null: false
      t.integer :claim_index
      t.text :raw_value
      t.jsonb :value, default: {}, null: false
      t.jsonb :reviewed_value
      t.text :evidence_url
      t.string :parser_id
      t.string :ruleset_version
      t.datetime :retrieved_at
      t.timestamps
    end
    add_index :catalog_assertions, [ :processing_record_id, :assertion_key ], unique: true,
      name: "index_catalog_assertions_on_record_and_key"
    add_index :catalog_assertions, [ :catalog_part_id, :assertion_type, :status ], name: "index_catalog_assertions_for_part_resolution"
    add_index :catalog_assertions, [ :source_key, :status, :assertion_type ], name: "index_catalog_assertions_for_source_review"
    add_check_constraint :catalog_assertions,
      "status IN ('candidate', 'reviewed', 'verified', 'conflict', 'rejected')", name: "catalog_assertions_status_check"

    create_table :knowledge_release_assertions do |t|
      t.references :knowledge_release, type: :uuid, null: false, foreign_key: true
      t.references :catalog_assertion, null: false, foreign_key: true
      t.jsonb :entry_snapshot, default: {}, null: false
      t.timestamps
    end
    add_index :knowledge_release_assertions, [ :knowledge_release_id, :catalog_assertion_id ], unique: true,
      name: "index_release_assertions_on_release_and_assertion"
  end
end
