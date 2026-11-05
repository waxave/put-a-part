class AddVehicleReferenceResolution < ActiveRecord::Migration[8.1]
  def change
    add_column :vehicle_candidates, :resolution_status, :string, null: false, default: "unresolved"
    add_check_constraint :vehicle_candidates,
      "resolution_status IN ('unresolved', 'matched', 'partial', 'ambiguous', 'no_match')",
      name: "vehicle_candidates_resolution_status_check"

    create_table :vehicle_candidate_matches do |t|
      t.references :vehicle_candidate, null: false, foreign_key: true
      t.references :vehicle_configuration, null: false, foreign_key: true
      t.string :external_system, null: false
      t.string :source_version, null: false
      t.string :match_reason, null: false
      t.timestamps
    end
    add_index :vehicle_candidate_matches,
      [ :vehicle_candidate_id, :vehicle_configuration_id, :external_system, :source_version ], unique: true,
      name: "index_vehicle_candidate_matches_on_candidate_config_version"
    add_index :vehicle_candidate_matches, [ :external_system, :source_version ], name: "index_vehicle_candidate_matches_on_reference_version"
  end
end
