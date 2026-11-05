class AddCatalogKeyToAttributeDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :attribute_definitions, :catalog_key, :string
    add_index :attribute_definitions, :catalog_key, unique: true
  end
end
