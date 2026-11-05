class CreateVehicleCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicle_candidates do |t|
      t.references :processing_record, null: false, foreign_key: true
      t.references :catalog_part, foreign_key: true
      t.references :catalog_observation, foreign_key: true
      t.references :vehicle_configuration, foreign_key: true
      t.string :assertion_key, null: false
      t.string :source_key, null: false
      t.integer :claim_index
      t.string :make_candidate
      t.string :model_candidate
      t.integer :model_year_start
      t.integer :model_year_end
      t.string :engine_code_candidate
      t.jsonb :qualifiers, default: {}, null: false
      t.text :raw_text, null: false
      t.string :parse_status, null: false, default: "candidate"
      t.string :parser_id
      t.string :ruleset_version
      t.timestamps
    end
    add_index :vehicle_candidates, [ :processing_record_id, :assertion_key ], unique: true,
      name: "index_vehicle_candidates_on_record_and_key"
    add_index :vehicle_candidates, [ :make_candidate, :model_candidate, :model_year_start, :model_year_end ],
      name: "index_vehicle_candidates_for_matching"
    add_index :vehicle_candidates, [ :source_key, :parse_status ], name: "index_vehicle_candidates_for_review"
    add_check_constraint :vehicle_candidates,
      "parse_status IN ('candidate', 'interpreted', 'unresolved', 'reviewed', 'conflict', 'rejected')",
      name: "vehicle_candidates_parse_status_check"

    add_reference :catalog_assertions, :vehicle_candidate, foreign_key: true
  end
end
