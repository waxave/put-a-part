class AddVehicleKindsGenerationsAndEngines < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :vehicle_models, :vehicle_kind, :string
    remove_index :vehicle_models, name: "index_vehicle_models_on_vehicle_make_id_and_normalized_name",
      algorithm: :concurrently
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY index_vehicle_models_on_make_kind_and_name
      ON vehicle_models (vehicle_make_id, normalized_name, (COALESCE(vehicle_kind, 'unspecified')))
    SQL

    create_table :vehicle_generations do |t|
      t.references :vehicle_model, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.integer :year_start
      t.integer :year_end
      t.string :body_type
      t.jsonb :attributes, null: false, default: {}
      t.timestamps
    end
    add_index :vehicle_generations, [ :vehicle_model_id, :normalized_name ], unique: true,
      name: "index_vehicle_generations_on_model_and_name"
    add_check_constraint :vehicle_generations,
      "(year_start IS NULL OR year_start BETWEEN 1886 AND 2100) AND (year_end IS NULL OR year_end BETWEEN 1886 AND 2100) AND (year_start IS NULL OR year_end IS NULL OR year_end >= year_start)",
      name: "vehicle_generations_valid_year_range"

    create_table :vehicle_engine_variants do |t|
      t.references :vehicle_generation, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :fuel_type
      t.integer :cylinder_count
      t.integer :displacement_cc
      t.decimal :power_hp, precision: 8, scale: 2
      t.decimal :torque_nm, precision: 8, scale: 2
      t.string :transmission
      t.string :drivetrain
      t.jsonb :specifications, null: false, default: {}
      t.timestamps
    end
    add_index :vehicle_engine_variants, [ :vehicle_generation_id, :normalized_name ], unique: true,
      name: "index_vehicle_engines_on_generation_and_name"

    add_reference :vehicle_reference_records, :vehicle_generation, foreign_key: true
    add_reference :vehicle_reference_records, :vehicle_engine_variant, foreign_key: true
    add_reference :vehicle_search_entries, :vehicle_generation, foreign_key: true
    add_reference :vehicle_search_entries, :vehicle_engine_variant, foreign_key: true
    remove_check_constraint :vehicle_search_entries, name: "vehicle_search_entries_one_entity_check"
    add_check_constraint :vehicle_search_entries,
      "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id, vehicle_generation_id, vehicle_engine_variant_id) = 1",
      name: "vehicle_search_entries_one_entity_check"
  end

  def down
    remove_check_constraint :vehicle_search_entries, name: "vehicle_search_entries_one_entity_check"
    remove_reference :vehicle_search_entries, :vehicle_engine_variant, foreign_key: true
    remove_reference :vehicle_search_entries, :vehicle_generation, foreign_key: true
    add_check_constraint :vehicle_search_entries,
      "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id) = 1",
      name: "vehicle_search_entries_one_entity_check"
    remove_reference :vehicle_reference_records, :vehicle_engine_variant, foreign_key: true
    remove_reference :vehicle_reference_records, :vehicle_generation, foreign_key: true
    drop_table :vehicle_engine_variants
    drop_table :vehicle_generations
    remove_index :vehicle_models, name: "index_vehicle_models_on_make_kind_and_name", algorithm: :concurrently
    add_index :vehicle_models, [ :vehicle_make_id, :normalized_name ], unique: true,
      name: "index_vehicle_models_on_vehicle_make_id_and_normalized_name", algorithm: :concurrently
    remove_column :vehicle_models, :vehicle_kind
  end
end
