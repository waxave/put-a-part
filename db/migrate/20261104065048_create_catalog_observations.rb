class CreateCatalogObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_observations do |t|
      t.references :processing_record, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :source_url, null: false
      t.string :source_sku, null: false
      t.string :status, null: false, default: "candidate"
      t.jsonb :claims, null: false, default: []
      t.string :content_sha256
      t.datetime :retrieved_at
      t.timestamps
    end
    add_index :catalog_observations, [ :processing_record_id, :source_key, :source_url ],
      unique: true, name: "index_catalog_observations_on_record_and_source"
  end
end
