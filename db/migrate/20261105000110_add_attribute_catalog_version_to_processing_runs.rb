class AddAttributeCatalogVersionToProcessingRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :processing_runs, :attribute_catalog_version, :string
  end
end
