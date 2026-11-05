# Put a Part

Put a Part es una aplicación para procesar archivos de proveedores de autopartes. Extrae datos de productos respaldados por la fuente y candidatos de vehículos y especificaciones, y genera un catálogo trazable de seis hojas en Excel. No realiza búsquedas en catálogos externos ni presenta aplicaciones no verificadas como ajustes confirmados.

El proyecto implementa una primera versión funcional del procesamiento, no toda la plataforma ETL propuesta. Consulta [Arquitectura](ARCHITECTURE.md) y [Hoja de ruta](ROADMAP.md) para conocer el estado actual. El [plan de arquitectura e implementación](docs/automotive-catalog-etl-architecture-plan.md) es una propuesta histórica y no describe el comportamiento actual.

## Configuración de desarrollo

- Se requieren Ruby 4.0.9, Bundler, Rails 8.1, PostgreSQL y Redis.
- Configura `PGHOST`, `PGPORT`, `PGUSER` y `PGPASSWORD` para un rol de PostgreSQL con permisos para crear bases de datos locales. De forma predeterminada se usa `localhost:5432` y el usuario `postgres`. También puedes configurar `DATABASE_URL`, la variable estándar de Rails.
- La interfaz de archivos no requiere autenticación y está pensada para una red local de confianza. Configura `APP_USERNAME` y `APP_PASSWORD` con valores no vacíos para proteger el panel `/sidekiq`; protege la aplicación y los archivos cargados mediante la red y el entorno de despliegue.
- Define `REDIS_URL` si Redis no está disponible en `redis://127.0.0.1:6379/0`. Instala las dependencias y prepara la base de datos con `bin/setup --skip-server`. `bin/dev` inicia Rails y Sidekiq. Si inicias Rails por separado, inicia también un worker con `bundle exec sidekiq -C config/sidekiq.yml`.
- Después de aplicar migraciones a una base de datos existente, ejecuta `bin/rails db:seed` para instalar o actualizar el catálogo versionado de atributos en español que se usa en las exportaciones XLSX.
- Ejecuta las pruebas RSpec con `bundle exec rspec`, las pruebas Rails con `bin/rails test`, las comprobaciones de estilo con `bin/rubocop` y el flujo de CI con `bin/ci`.
- `bin/setup` limpia los registros y archivos temporales. `bin/ci` ejecuta `db:seed` en el entorno de pruebas antes de correrlas; revisa su configuración antes de ejecutarla contra cualquier base de datos.

La aplicación acepta archivos XLSX con el formato de ejemplo `Origen` o el formato genérico `Products`, cuyas columnas se pueden mapear, y exporta las seis hojas de la plantilla. `Catálogo` contiene campos de producto respaldados por la fuente; la taxonomía queda vacía cuando no se puede resolver. `Atributos` utiliza el catálogo versionado `attribute_definitions` para las clases, nombres y unidades en español. Entre los datos admitidos están el código y la familia del motor, el número de cilindros y válvulas, la cilindrada, el tipo de árbol de levas, algunos atributos de producto y las dimensiones de anillos. Los datos desconocidos y los candidatos de vehículos no se exportan como atributos. Se conserva la confianza de cada candidato y su evidencia de origen: estos datos no son especificaciones, aplicaciones ni intercambios verificados. La extracción de años usa el umbral de dos dígitos 30; la interpretación del texto de vehículos es léxica y solo genera candidatos. La extracción de cilindrada es heurística y no la vincula con un vehículo o motor específico. La búsqueda en referencias locales de vehículos no demuestra que una pieza sea compatible. El identificador de conocimiento `empty-v1` representa una base inicial de resolución vacía. Los archivos se guardan mediante Active Storage local; cambiar la configuración de la base de datos no migra ni elimina archivos SQLite anteriores.

La interfaz web bilingüe está en `/`, con español como idioma predeterminado y un selector de idioma en el encabezado. No hay una API JSON. Los procesamientos en cola se pueden cancelar de inmediato; los que ya están activos se detienen en puntos de control. Los procesamientos finalizados con un archivo de entrada se pueden volver a ejecutar como nuevos procesamientos usando el perfil y las reglas actuales. Como la interfaz no tiene inicio de sesión, despliega la aplicación únicamente en un entorno de confianza y protege los archivos cargados y descargados, PostgreSQL, Redis y el almacenamiento persistente en la capa de red y despliegue. El panel de Sidekiq tiene protección independiente en `/sidekiq`.

## Extracción y referencias de vehículos

El procesamiento extrae los datos y genera la exportación de inmediato. El comportamiento actual no incluye búsquedas en proveedores externos ni flujos de investigación o revisión. Los datos extraídos de vehículos y especificaciones siguen siendo candidatos, no aplicaciones verificadas. Se conservan los procesamientos, observaciones y versiones de conocimiento existentes. El catálogo normalizado de vehículos se utiliza para búsquedas locales y es independiente de la investigación externa.

Los rangos de años aceptan barras o guiones y años de dos o cuatro dígitos (por ejemplo, `99/04`, `1999/04`, `99/2004`, `1999-2004`). El umbral predeterminado para años de dos dígitos es 30 (`00–30` → 2000–2030; `31–99` → 1931–1999). Los resultados siguen siendo candidatos y se señalan los rangos implausibles. Cambia `year_cutoff:` en `Automotive::Parsers::DescriptionParser.call` solo al versionar explícitamente un nuevo conjunto de reglas. Las tablas normalizadas conservan variantes exactas de piezas, afirmaciones de origen, candidatos de vehículos e identificadores externos ACES/PIES opcionales. Los adaptadores SQLite locales importan los formatos documentados de gor3a y VehiclesDB. La asociación de candidatos con referencias locales no demuestra compatibilidad entre una pieza y un vehículo. No se incluye una base de datos con licencia VCdb/PCdb/PAdb ni un cliente de API de referencias de vehículos.

### Importar el catálogo de referencias de vehículos

El catálogo unificado de vehículos importa archivos SQLite proporcionados localmente a PostgreSQL. Admite los esquemas fijados de [gor3a/vehicle-makes-models](https://github.com/gor3a/vehicle-makes-models) y [VehiclesDB](https://github.com/vehiclesdb/vehiclesdb). Primero ejecuta una validación sin aplicar cambios:

```sh
bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=/data/vehicles.sqlite
bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=/data/catalog.sqlite VEHICLESDB_ATTRIBUTION_PATH=/data/ATTRIBUTION.md
```

Agrega `APPLY=true` para guardar los registros de origen y la jerarquía canónica de marca, modelo, generación y motor. Las importaciones se procesan en lotes, se pueden repetir y no descargan datos ni modifican procesamientos o versiones de conocimiento. Después de importar, crea la proyección de búsqueda de texto completo de PostgreSQL con `bin/rails automotive_catalog:rebuild_vehicle_search`.

La importación registra la revisión de origen, el SHA-256 del artefacto, la licencia y la atribución. La importación de VehiclesDB requiere el archivo `ATTRIBUTION.md` correspondiente junto al artefacto o en la ruta indicada por la variable de entorno, y guarda sus avisos de origen. Los **datos** de gor3a usan ODbL 1.0 (atribución a vehicle-makes-models y autoevolution.com, con obligaciones de compartir bajo la misma licencia); VehiclesDB usa CC-BY 4.0 y requiere su crédito y los avisos del registro de origen. Revisa esos términos antes de distribuir una base de datos combinada o derivada. Las descargas independientes de vPIC están destinadas a decodificar VIN y no se importan como taxonomía de vehículos. Este catálogo está orientado a ACES/PIES, pero no está certificado ni declara conformidad; los identificadores oficiales con licencia y la validación contra versiones objetivo son tareas independientes.

La asociación de candidatos de vehículos solo utiliza el catálogo de referencias importado localmente. La extracción del texto del modelo es conservadora: las especificaciones y los términos de motor delimitan el texto del modelo, y las coincidencias ambiguas deben permanecer sin resolver en lugar de tratarse como aplicaciones confirmadas.

## Documentación

- [Manifiesto para agentes](AGENTS.md)
- [Arquitectura](ARCHITECTURE.md)
- [Hoja de ruta](ROADMAP.md)
- [Auditoría de la implementación actual](docs/architecture-implementation-audit.md)
- [Plan de arquitectura ETL](docs/automotive-catalog-etl-architecture-plan.md)
