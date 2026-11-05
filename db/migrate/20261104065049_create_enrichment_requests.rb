class CreateEnrichmentRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :enrichment_requests do |t|
      t.references :processing_record, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :status, null: false, default: "queued"
      t.integer :attempt_count, null: false, default: 0
      t.string :last_error_code
      t.text :last_error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :enrichment_requests, [ :processing_record_id, :source_key ], unique: true,
      name: "index_enrichment_requests_on_record_and_source"
  end
end
