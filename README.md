# Put a Part

Put a Part es una aplicación Rails para procesar archivos de proveedores de autopartes. Extrae datos de producto respaldados por la fuente y candidatos de vehículos y especificaciones, investiga piezas con Autofacts y genera un catálogo trazable de seis hojas en Excel.

Las aplicaciones, los intercambios y las afirmaciones externas son **candidatos no verificados**, no compatibilidades confirmadas. Consulta [Arquitectura](ARCHITECTURE.md) y [Hoja de ruta](ROADMAP.md) para el estado actual y los límites del sistema. El [plan de arquitectura ETL](docs/automotive-catalog-etl-architecture-plan.md) es una propuesta histórica y no describe el comportamiento actual.

## Stack

- **Ruby 4.0.9**, **Rails 8.1**, Bundler y PostgreSQL.
- Active Job con **Sidekiq** y **Redis**; Active Storage local.
- **Autofacts** con su propio catálogo SQLite (`config/autofacts.yml`, predeterminado: `autofacts.sqlite3`).
- **Hotwire** (Turbo y Stimulus), import maps y Propshaft; no se requiere Node.js.
- Pruebas con **Minitest** y **RSpec**, además de RuboCop, Brakeman y bundler-audit.

La interfaz es bilingüe con español por defecto. Admite dos perfiles XLSX: `Origen` (formato de ejemplo) y `Products` (columnas mapeables). Para cada pieza elegible se ejecuta la investigación de Autofacts antes de la exportación; la descarga se habilita al finalizar.

> **Sin autenticación.** La aplicación no tiene inicio de sesión. No la expongas a redes no confiables; el panel de Sidekiq en `/sidekiq` se protege por separado con `APP_USERNAME` y `APP_PASSWORD`.

## Requisitos

- [mise](https://mise.jdx.dev/getting-started.html) para fijar las versiones de Ruby, PostgreSQL y Redis.
- Git y las herramientas de compilación/bibliotecas de desarrollo que requiera tu sistema (compilador C/C++, `make`, OpenSSL, libyaml, zlib, libpq y SQLite). Los nombres de los paquetes dependen de la distribución.
- Para las pruebas de sistema: un navegador y su controlador compatibles con Selenium.

`mise.toml` fija **Ruby 4.0.9**, **PostgreSQL 18.1** y **Redis 8.8.0**, y carga `.env` y `.env.local`. Desde la raíz del repositorio:

```sh
mise trust
mise install
```

Esto instala los ejecutables, pero **no inicializa ni inicia los servidores** de PostgreSQL y Redis: tienes que hacerlo aparte (ver más abajo).

## Configuración

Crea un archivo de entorno local a partir del ejemplo y edítalo con tus valores:

```sh
cp .env.example .env.local
```

```sh
PGUSER = "some_user"
PGPASSWORD = "some_password"
APP_USERNAME = "some_user"
APP_PASSWORD = "some_password"
```

Variables de conexión relevantes (con sus valores predeterminados):

| Variable | Predeterminado | Uso |
|---|---|---|
| `PGHOST` | `localhost` | Host de PostgreSQL |
| `PGPORT` | `5432` | Puerto de PostgreSQL |
| `PGUSER` | `postgres` | Usuario de PostgreSQL |
| `PGPASSWORD` | — | Contraseña de PostgreSQL |
| `REDIS_URL` | `redis://127.0.0.1:6379/0` | Conexión a Redis |
| `DATABASE_URL` | — | Alternativa estándar a las variables `PG*` |
| `APP_USERNAME` / `APP_PASSWORD` | — | Credenciales del panel `/sidekiq` |
| `AUTOFACTS_DATABASE_PATH` | `autofacts.sqlite3` | Ruta opcional del SQLite de Autofacts |

`.env` y `.env.local` están ignorados por Git: no publiques contraseñas.

## Ejecutar con mise

### 1. Iniciar PostgreSQL y Redis

Inicia un servidor PostgreSQL y uno Redis con los servicios de tu sistema o con instancias locales ya configuradas. En PostgreSQL necesitas un rol con permiso para crear `put_a_part_development` y `put_a_part_test`.

Si no tienes servidores y quieres crear instancias nuevas con los ejecutables de mise, este es un ejemplo para desarrollo. Elige un directorio que **no exista**:

```sh
export PGDATA="$HOME/.local/share/put-a-part/postgres"
mkdir -p "$(dirname "$PGDATA")"
initdb -D "$PGDATA" -U postgres --auth-local=trust --auth-host=scram-sha-256 --pwprompt
pg_ctl -D "$PGDATA" -l "$(dirname "$PGDATA")/postgres.log" start
```

Configura `PGUSER=postgres` y `PGPASSWORD` con esa contraseña. En otra terminal, inicia Redis:

```sh
redis-server --bind 127.0.0.1 --port 6379
```

Comprueba que están accesibles:

```sh
pg_isready -h "${PGHOST:-localhost}" -p "${PGPORT:-5432}"
redis-cli -u "${REDIS_URL:-redis://127.0.0.1:6379/0}" ping
```

Redis debe responder `PONG`. No uses `initdb` ni `pg_ctl` con un directorio de datos ajeno.

### 2. Instalar dependencias y preparar la base

```sh
bundle install
bin/rails db:prepare
bundle exec autofacts install
bin/rails db:seed
```

O, en un solo paso idempotente que además limpia registros y archivos temporales:

```sh
bin/setup --skip-server
```

### 3. Iniciar la aplicación

```sh
bin/dev
```

Esto inicia Rails en <http://localhost:3000> y un worker Sidekiq. Para iniciar los procesos por separado:

```sh
bin/rails server
```

```sh
bundle exec sidekiq -C config/sidekiq.yml
```

Abre <http://localhost:3000>, carga un archivo XLSX y sigue el progreso. El estado se consulta en <http://localhost:3000/up> y el panel del worker en <http://localhost:3000/sidekiq>.

### 4. Pruebas y comprobaciones

```sh
bundle exec rspec
bin/rails test
bin/rubocop
bin/ci
```

`bin/ci` ejecuta las comprobaciones y pruebas configuradas; revisa `config/ci.rb` antes de usarlo (carga semillas en la base de pruebas).

## Ejecutar con mise y Make

El `Makefile` envuelve los comandos anteriores. Los objetivos sin prefijo operan sobre la instalación local de mise; los objetivos con prefijo `docker-` operan sobre los contenedores.

| Objetivo | Acción |
|---|---|
| `make help` | Lista todos los objetivos disponibles |
| `make init` | `mise install` + `bundle install` + `db:prepare` + `db:seed` + `autofacts install` |
| `make setup` | Alias de `make init` |
| `make dev` | Inicia Rails y Sidekiq con `bin/dev` |
| `make test` | Ejecuta RSpec y las pruebas Rails |
| `make lint` | Ejecuta RuboCop |

> `make init` **no inicia** PostgreSQL ni Redis: deja los servidores de la sección anterior en marcha antes de ejecutarlo. Tampoco crea `.env`; configúralo primero como se indica arriba.

Ejemplo de flujo completo:

```sh
make init
make dev
make test
make lint
```

### Referencias de vehículos con mise + Make

Estos objetivos validan o importan los catálogos locales descritos en [Referencias de vehículos](#referencias-de-vehículos):

```sh
make vehicle-gor3a-check
make vehicle-vehiclesdb-check
```

```sh
make vehicle-gor3a-import
make vehicle-vehiclesdb-import
make vehicle-index
```

## Ejecutar con Docker y Make

La configuración Docker usa `compose.yaml` y un archivo de entorno propio.

### 1. Configurar el entorno Docker

```sh
cp .env.docker.example .env.docker
```

```sh
DOCKER_POSTGRES_PASSWORD=replace-with-a-local-database-password
APP_USERNAME=replace-with-a-dashboard-user
APP_PASSWORD=replace-with-a-dashboard-password
DOCKER_WEB_PORT=3000
```

### 2. Preparar los datos de vehículos

El contenedor `init` importa automáticamente los catálogos. Coloca `gor3a.sqlite`, `vehiclesdb.sqlite` y el `ATTRIBUTION.md` correspondiente en `data/` antes de preparar Docker.

### 3. Construir e iniciar

```sh
make docker-setup
```

Esto construye la imagen y levanta PostgreSQL, Redis, un proceso de preparación, Rails y Sidekiq. La preparación migra la base de desarrollo, carga las semillas y prepara Autofacts antes de iniciar `web` y `worker`.

```sh
make docker-ps
make docker-logs
make docker-down
```

- `make docker-ps` muestra el estado de los contenedores.
- `make docker-logs` sigue los registros.
- `make docker-down` detiene y elimina los contenedores **sin borrar los volúmenes** (PostgreSQL, Redis, Active Storage y el SQLite de Autofacts son persistentes).
- `make docker-up` construye la imagen y reinicia los servicios; `make docker-init` y `make docker-setup` preparan e inician el entorno (equivalentes a `docker-up`).

Abre <http://localhost:3000> (o el puerto de `DOCKER_WEB_PORT`). El servidor solo publica el puerto en `127.0.0.1`, pero la aplicación no tiene inicio de sesión: es una configuración de **desarrollo local**, no apta para producción.

### Referencias de vehículos con Docker + Make

```sh
make docker-vehicle-gor3a-check
make docker-vehicle-vehiclesdb-check
```

```sh
make docker-vehicle-gor3a-import
make docker-vehicle-vehiclesdb-import
make docker-vehicle-index
```

Los objetivos `-import` escriben en el PostgreSQL de Docker y pueden tardar; no ejecutes importaciones simultáneas.

## Referencias de vehículos

La aplicación puede ejecutarse sin este catálogo, pero la búsqueda local de marcas, modelos y tipos de vehículo estará vacía hasta importarlo. Los archivos se guardan en `data/` **dentro del proyecto**:

| Archivo | Contenido |
|---|---|
| `data/gor3a.sqlite` | Catálogo SQLite gor3a de marcas, modelos, generaciones y motores |
| `data/vehiclesdb.sqlite` | Catálogo SQLite de VehiclesDB |
| `data/ATTRIBUTION.md` | Avisos de atribución de la versión de VehiclesDB |

Obtén los artefactos compatibles de [gor3a](https://github.com/gor3a/vehicle-makes-models) y [VehiclesDB](https://github.com/vehiclesdb/vehiclesdb), junto con la atribución de la misma versión. El importador no los descarga.

Primero valida **sin modificar PostgreSQL** (objetivos `*-check`), y solo si tienes autorización impórtalos (`*-import`) y reconstruye el índice (`vehicle-index` / `docker-vehicle-index`).

- Los datos de gor3a usan **ODbL 1.0**; VehiclesDB usa **CC-BY 4.0** y exige su crédito y los avisos de sus fuentes. Revisa las licencias antes de redistribuir.
- Las coincidencias locales son candidatos y **no** demuestran compatibilidad de piezas.

## Autofacts

La investigación consulta primero la pieza por número y marca; si no obtiene un resultado utilizable, programa una búsqueda alternativa al menos 30 segundos después. Las observaciones y aplicaciones siguen siendo candidatas. Respeta las condiciones de acceso de AutoFactsDB.

- Instalar o actualizar el esquema y la taxonomía local: `bundle exec autofacts install`.
- Comprobar una búsqueda: `bundle exec autofacts subcategory "PISTONES"`.
- Rails, `make init` y la CLI comparten `AUTOFACTS_DATABASE_PATH` o `config/autofacts.yml`.

Tras cambiar las reglas o el catálogo, usa **Volver a procesar** para crear un nuevo procesamiento; los XLSX ya exportados no se modifican.

## Solución de problemas

- **No conecta a PostgreSQL:** revisa `pg_isready`, las variables `PG*`, la contraseña y los permisos de creación de bases.
- **El procesamiento permanece en investigación:** comprueba Redis y que el worker de Sidekiq esté activo; la investigación externa requiere acceso autorizado a Autofacts.
- **Falta Sistema o Subsistema:** comprueba `bundle exec autofacts subcategory "PISTONES"` y que Rails y la CLI usan la misma ruta de Autofacts.
- **No se encuentran modelos:** verifica los archivos de `data/`, que importaste con `APPLY=true` (objetivos `*-import`) y que reconstruiste el índice.
- **No hay descarga:** espera a que termine la investigación y la generación del archivo; revisa las incidencias y el panel de Sidekiq.

## Documentación

- [Manifiesto para agentes](AGENTS.md)
- [Arquitectura](ARCHITECTURE.md)
- [Hoja de ruta](ROADMAP.md)
- [Auditoría de la implementación actual](docs/architecture-implementation-audit.md)
- [Plan de arquitectura ETL](docs/automotive-catalog-etl-architecture-plan.md)
