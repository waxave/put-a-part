module Catalog
  # Observed worksheet layout, not a claim about the completeness of its data.
  module WorkbookContract
    SHEETS = [ "Origen", "Métricas", "Aplicaciones", "Intercambios", "Atributos", "Catálogo" ].freeze

    HEADERS = {
      "Origen" => [ "Cod interno", "Número de parte", "Descripción del artículo", "Descripcion", "Grupo de articulos", "Fabricante", "Unidad" ],
      "Aplicaciones" => [ "Referencia", "Marca", "Producto", "Posición", "Fabricante", "Modelo", "Submodelo", "Año", "Litros", "CC", "CID", "Cilindros", "Bloque", "Combustible", "Mercado" ],
      "Intercambios" => [ "Referencia", "Marca", "Producto", "Intercambio", "Marca intercambio", "Origen" ],
      "Atributos" => [ "Referencia", "Marca", "Producto", "Clase", "Atributo", "Unidad", "Valor" ],
      "Catálogo" => [ "Referencia", "Marca", "Categoría", "Sistema", "Subsistema", "Producto", "Descripción" ]
    }.transform_values(&:freeze).freeze

    METRIC_LABELS = {
      1 => "Catálogo Bonaparte - Refaccionaria Trópico de Cáncer",
      2 => "Referencias:", 4 => "Aplicaciones", 5 => "Origen", 6 => "Incrementos",
      8 => "Intercambios", 9 => "Origen", 10 => "Incrementos",
      12 => "Atributos", 13 => "Origen", 14 => "Incrementos"
    }.freeze
  end
end
