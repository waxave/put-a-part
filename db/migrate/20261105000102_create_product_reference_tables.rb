class CreateProductReferenceTables < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_product_categories do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :external_system
      t.string :external_id
      t.string :source_version
      t.timestamps
    end
    add_index :catalog_product_categories, :normalized_name, unique: true
    add_index :catalog_product_categories, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_product_categories_on_external_identity"
    add_reference :catalog_parts, :catalog_product_category, foreign_key: true

    create_table :part_identifiers do |t|
      t.references :catalog_part, null: false, foreign_key: true
      t.references :catalog_observation, foreign_key: true
      t.string :identifier_type, null: false
      t.string :identifier_value, null: false
      t.string :normalized_identifier, null: false
      t.string :source_key, null: false
      t.timestamps
    end
    add_index :part_identifiers, [ :catalog_part_id, :identifier_type, :normalized_identifier ], unique: true,
      name: "index_part_identifiers_on_part_type_and_value"

    create_table :attribute_definitions do |t|
      t.string :attribute_class, null: false, default: ""
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :default_unit
      t.string :external_system
      t.string :external_id
      t.string :source_version
      t.timestamps
    end
    add_index :attribute_definitions, [ :attribute_class, :normalized_name ], unique: true, name: "index_attribute_definitions_on_class_and_name"
    add_index :attribute_definitions, [ :external_system, :external_id ], unique: true,
      where: "external_system IS NOT NULL AND external_id IS NOT NULL", name: "index_attribute_definitions_on_external_identity"
    add_reference :catalog_assertions, :attribute_definition, foreign_key: true
  end
end
