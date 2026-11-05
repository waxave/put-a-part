# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

attribute_catalog = [
  [ "engine_code", "Motor", "Código de motor", nil ],
  [ "engine_family", "Motor", "Familia de motor", nil ],
  [ "cylinder_count", "Número", "Número de cilindros", nil ],
  [ "displacement_liters", "Motor", "Cilindrada", "L" ],
  [ "valve_count", "Número", "Número de válvulas", nil ],
  [ "camshaft_type", "Motor", "Tipo de árbol de levas", nil ],
  [ "diameter", "Diámetro", "Diámetro", "mm" ],
  [ "gasket_material", "Material", "Material de junta de culata", nil ],
  [ "tooth_count", "Dientes", "Número de dientes", "dientes" ],
  [ "ring_diameter", "Anillo", "Diámetro de anillo", "mm" ],
  [ "ring_width_1", "Anillo", "Espesor de anillo 1", "mm" ],
  [ "ring_width_2", "Anillo", "Espesor de anillo 2", "mm" ],
  [ "ring_width_3", "Anillo", "Espesor de anillo 3", "mm" ]
]

attribute_catalog.each do |catalog_key, attribute_class, name, default_unit|
  definition = AttributeDefinition.find_or_initialize_by(catalog_key: catalog_key)
  definition.assign_attributes(attribute_class: attribute_class, name: name, default_unit: default_unit, source_version: "attribute-catalog-v1")
  definition.save!
end
