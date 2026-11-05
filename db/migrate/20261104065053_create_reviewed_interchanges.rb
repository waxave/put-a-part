class CreateReviewedInterchanges < ActiveRecord::Migration[8.1]
  def change
    create_table :reviewed_interchanges do |t|
      t.references :catalog_observation, null: false, foreign_key: true
      t.integer :claim_index, null: false
      t.string :reference, null: false
      t.string :brand, null: false
      t.text :evidence_url, null: false
      t.timestamps
    end
    add_index :reviewed_interchanges, [ :catalog_observation_id, :claim_index ], unique: true, name: "index_reviewed_interchanges_on_observation_and_claim"
  end
end
