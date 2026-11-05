class CreateReviewedAttributes < ActiveRecord::Migration[8.1]
  def change
    create_table :reviewed_attributes do |t|
      t.references :catalog_observation, null: false, foreign_key: true
      t.integer :claim_index, null: false
      t.string :attribute_class, null: false
      t.string :name, null: false
      t.string :unit
      t.text :value, null: false
      t.timestamps
    end
    add_index :reviewed_attributes, [ :catalog_observation_id, :claim_index ], unique: true, name: "index_reviewed_attributes_on_observation_and_claim"
  end
end
