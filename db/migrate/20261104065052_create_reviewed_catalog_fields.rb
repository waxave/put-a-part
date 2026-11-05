class CreateReviewedCatalogFields < ActiveRecord::Migration[8.1]
  def change
    create_table :reviewed_catalog_fields do |t|
      t.references :catalog_observation, null: false, foreign_key: true
      t.integer :claim_index, null: false
      t.string :field, null: false
      t.text :value, null: false
      t.timestamps
    end
    add_index :reviewed_catalog_fields, [ :catalog_observation_id, :claim_index, :field ], unique: true, name: "index_reviewed_catalog_fields_on_claim_and_field"
  end
end
