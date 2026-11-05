class CreateProcessingRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :processing_runs, id: :uuid do |t|
      t.string :status, null: false, default: "queued"
      t.string :stage, null: false, default: "queued"
      t.string :format_key
      t.string :format_version
      t.string :ruleset_version
      t.string :knowledge_release_id
      t.string :export_schema_version
      t.string :input_sha256
      t.integer :total_records, null: false, default: 0
      t.integer :processed_records, null: false, default: 0
      t.integer :successful_records, null: false, default: 0
      t.integer :warning_records, null: false, default: 0
      t.integer :failed_records, null: false, default: 0
      t.integer :progress_percent, null: false, default: 0
      t.integer :attempt_count, null: false, default: 0
      t.string :last_error_code
      t.text :last_error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :processing_runs, [ :status, :created_at ]

    create_table :processing_records do |t|
      t.references :processing_run, null: false, type: :uuid, foreign_key: true
      t.string :source_sheet, null: false
      t.integer :source_row, null: false
      t.string :source_sku
      t.string :status, null: false, default: "pending"
      t.jsonb :normalized_product, null: false, default: {}
      t.jsonb :facts, null: false, default: []
      t.jsonb :unresolved, null: false, default: []
      t.datetime :processed_at
      t.timestamps
    end
    add_index :processing_records, [ :processing_run_id, :source_sheet, :source_row ], unique: true, name: "index_processing_records_on_run_and_source"

    create_table :processing_issues do |t|
      t.references :processing_run, null: false, type: :uuid, foreign_key: true
      t.references :processing_record, foreign_key: true
      t.string :stage, null: false
      t.string :severity, null: false
      t.string :code, null: false
      t.text :message, null: false
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end
  end
end
