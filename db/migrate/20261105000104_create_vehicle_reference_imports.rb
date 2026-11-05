class CreateVehicleReferenceImports < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicle_reference_datasets do |t|
      t.string :source_key, null: false
      t.string :source_version, null: false
      t.string :artifact_name, null: false
      t.string :sha256, null: false
      t.string :license_identifier
      t.text :attribution
      t.string :schema_version
      t.timestamps
    end
    add_index :vehicle_reference_datasets, [ :source_key, :source_version, :sha256 ], unique: true,
      name: "index_vehicle_reference_datasets_on_source_version_checksum"

    create_table :vehicle_reference_imports do |t|
      t.references :vehicle_reference_dataset, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.boolean :dry_run, null: false, default: true
      t.string :normalizer_version, null: false
      t.jsonb :counts, null: false, default: {}
      t.text :error_summary
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :vehicle_reference_imports, [ :vehicle_reference_dataset_id, :created_at ],
      name: "index_vehicle_reference_imports_on_dataset_and_created"
    add_check_constraint :vehicle_reference_imports,
      "status IN ('pending', 'running', 'validated', 'completed', 'failed', 'cancelled')",
      name: "vehicle_reference_imports_status_check"

    create_table :vehicle_reference_records do |t|
      t.references :vehicle_reference_dataset, null: false, foreign_key: true
      t.references :vehicle_make, foreign_key: true
      t.references :vehicle_model, foreign_key: true
      t.references :vehicle_configuration, foreign_key: true
      t.string :record_type, null: false
      t.string :source_record_id, null: false
      t.string :source_parent_id
      t.string :resolution_status, null: false, default: "unresolved"
      t.string :normalizer_version, null: false
      t.string :content_sha256, null: false
      t.jsonb :raw_record, null: false, default: {}
      t.jsonb :normalized_record, null: false, default: {}
      t.jsonb :validation_issues, null: false, default: []
      t.timestamps
    end
    add_index :vehicle_reference_records, [ :vehicle_reference_dataset_id, :source_record_id ], unique: true,
      name: "index_vehicle_reference_records_on_dataset_and_source_id"
    add_index :vehicle_reference_records, [ :record_type, :resolution_status ],
      name: "index_vehicle_reference_records_on_type_and_resolution"
    add_index :vehicle_reference_records, :content_sha256
    add_check_constraint :vehicle_reference_records,
      "resolution_status IN ('unresolved', 'matched', 'partial', 'ambiguous', 'conflict', 'rejected')",
      name: "vehicle_reference_records_resolution_check"

    create_table :vehicle_search_entries do |t|
      t.references :vehicle_make, foreign_key: true
      t.references :vehicle_model, foreign_key: true
      t.references :vehicle_configuration, foreign_key: true
      t.string :entry_type, null: false
      t.text :display_text, null: false
      t.text :normalized_text, null: false
      t.virtual :search_vector, type: :tsvector,
        as: "to_tsvector('simple', coalesce(display_text, ''))", stored: true
      t.timestamps
    end
    add_check_constraint :vehicle_search_entries,
      "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id) = 1",
      name: "vehicle_search_entries_one_entity_check"
    add_index :vehicle_search_entries, :search_vector, using: :gin
    add_index :vehicle_search_entries, :normalized_text, using: :btree
  end
end
