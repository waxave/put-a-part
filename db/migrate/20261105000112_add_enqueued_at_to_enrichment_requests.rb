class AddEnqueuedAtToEnrichmentRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :enrichment_requests, :enqueued_at, :datetime
  end
end
