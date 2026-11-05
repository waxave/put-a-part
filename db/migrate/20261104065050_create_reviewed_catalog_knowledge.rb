class CreateReviewedCatalogKnowledge < ActiveRecord::Migration[8.1]
  def change
    create_table :reviewed_applications do |t|
      t.references :catalog_observation, null: false, foreign_key: true
      t.integer :claim_index, null: false
      t.string :manufacturer, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.timestamps
    end
    add_index :reviewed_applications, [ :catalog_observation_id, :claim_index ], unique: true, name: "index_reviewed_applications_on_observation_and_claim"
    create_table :knowledge_releases, id: :uuid do |t|
      t.jsonb :entries, null: false, default: []
      t.timestamps
    end
  end
end
