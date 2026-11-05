class CreateVehicleAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicle_aliases do |t|
      t.references :vehicle_make, foreign_key: true
      t.references :vehicle_model, foreign_key: true
      t.references :vehicle_configuration, foreign_key: true
      t.string :alias_text, null: false
      t.string :normalized_alias, null: false
      t.string :source_key, null: false
      t.string :review_status, null: false, default: "candidate"
      t.text :evidence
      t.timestamps
    end
    add_check_constraint :vehicle_aliases,
      "num_nonnulls(vehicle_make_id, vehicle_model_id, vehicle_configuration_id) = 1",
      name: "vehicle_aliases_one_entity_check"
    add_check_constraint :vehicle_aliases,
      "review_status IN ('candidate', 'accepted', 'rejected')", name: "vehicle_aliases_review_status_check"
    add_index :vehicle_aliases, [ :vehicle_make_id, :normalized_alias ], unique: true,
      where: "vehicle_make_id IS NOT NULL", name: "index_vehicle_aliases_on_make_and_normalized_alias"
    add_index :vehicle_aliases, [ :vehicle_model_id, :normalized_alias ], unique: true,
      where: "vehicle_model_id IS NOT NULL", name: "index_vehicle_aliases_on_model_and_normalized_alias"
    add_index :vehicle_aliases, [ :vehicle_configuration_id, :normalized_alias ], unique: true,
      where: "vehicle_configuration_id IS NOT NULL", name: "index_vehicle_aliases_on_configuration_and_alias"
  end
end
