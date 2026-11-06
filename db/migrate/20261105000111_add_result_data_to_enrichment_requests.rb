class AddResultDataToEnrichmentRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :enrichment_requests, :result_data, :jsonb, null: false, default: {}
  end
end
