# Put a Part

Put a Part is an automotive workbook extraction application. It ingests supplier files, extracts source-backed product data and candidate vehicle/specification details, and produces a traceable six-sheet Excel catalog. It does not perform external catalog research or assert unverified fitments.

The repository contains an initial processing slice, not the complete ETL platform. See [Architecture](ARCHITECTURE.md) and [Roadmap](ROADMAP.md). The detailed [proposed architecture and implementation plan](docs/automotive-catalog-etl-architecture-plan.md) is the project baseline.

## Current development setup

- Ruby 4.0.9, Bundler, Rails 8.1, PostgreSQL and Redis are required.
- Set `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` for a PostgreSQL role that can create local databases; the defaults are localhost:5432 and user `postgres`. Alternatively configure Rails' standard `DATABASE_URL`.
- The workbook UI is unauthenticated and intended for a trusted local network. Configure nonempty `APP_USERNAME` and `APP_PASSWORD` only if you need the separately protected `/sidekiq` dashboard; protect the server and uploaded files at the network/deployment layer.
- Set `REDIS_URL` if Redis is not at `redis://127.0.0.1:6379/0`. Install dependencies and prepare the database with `bin/setup --skip-server`; `bin/dev` starts both the Rails server and the Sidekiq worker. If starting Rails separately, also start a worker with `bundle exec sidekiq -C config/sidekiq.yml`.
- After applying migrations to an existing database, run `bin/rails db:seed` to install/update the versioned Spanish attribute catalog used in XLSX exports.
- Run the catalog contract specs with `bundle exec rspec`, the existing Rails tests with `bin/rails test`, style checks with `bin/rubocop`, or the configured CI workflow with `bin/ci`.
- `bin/setup` clears logs and temporary files. `bin/ci` runs `db:seed` in the test environment before tests; inspect its configuration before running it against any database.

The app accepts XLSX files matching the sample `Origen` layout or the generic column-mapped `Products` layout, and exports the template's six sheets. `Catálogo` contains source-backed product fields; unresolved taxonomy fields remain blank. `Atributos` uses the versioned `attribute_definitions` catalog for Spanish classes, names and units. Supported facts include engine code/family, cylinder and valve counts, displacement, camshaft type, selected product attributes and ring dimensions. Unknown facts and vehicle candidates are not written as attributes. Candidate confidence and source evidence remain stored: these values are not independently verified specifications, fitments or interchanges. Year extraction uses a two-digit cutoff of 30; vehicle text parsing is lexical and candidate-only. Displacement extraction is heuristic and is not associated with a specific vehicle or engine. Vehicle reference matching uses locally imported data and does not prove part fitment. The `empty-v1` knowledge identifier denotes an empty resolver baseline. Files and results use local Active Storage; changing database configuration does not migrate or delete prior SQLite files.

The bilingual HTML UI is at `/`; Spanish is the default and the language switch is available in the header. The JSON API has been removed. Queued runs can be canceled immediately; active runs stop at processing checkpoints. Finished runs with an input can be reprocessed as new runs using the current profile and rules. Since the UI has no login, deploy it only in a trusted environment and secure uploads, downloads, PostgreSQL, Redis and persistent storage at the network/deployment layer. The Sidekiq dashboard remains separately protected at `/sidekiq`.

## Extraction and vehicle references

The extraction pipeline processes each workbook and exports immediately; there is no external provider search, JSON API, or research/review workflow in current runtime behavior. Extracted vehicle and specification values remain candidates, not verified fitments. Existing run, observation and knowledge-release data are retained. The normalized vehicle reference catalog is local matching data and remains separate from external research.

Description year ranges accept slash and dash forms with two- or four-digit years (for example, `99/04`, `1999/04`, `99/2004`, `1999-2004`). The default two-digit cutoff is 30 (`00–30` → 2000–2030; `31–99` → 1931–1999); parsed values remain candidates and implausible ranges are flagged. Pass a different `year_cutoff:` to `Automotive::Parsers::DescriptionParser.call` only when explicitly versioning a new ruleset. Normalized tables retain exact part variants, source assertions, vehicle candidates and optional external ACES/PIES reference IDs. Local SQLite adapters import the documented gor3a and VehiclesDB formats. Vehicle matching relates candidate text to local reference configurations; it does not assert that a part fits them. No licensed VCdb/PCdb/PAdb dataset or live vehicle-reference API client is bundled.

### Vehicle reference catalog import

The unified vehicle catalog imports locally supplied SQLite files into PostgreSQL. It supports the pinned schemas from [gor3a/vehicle-makes-models](https://github.com/gor3a/vehicle-makes-models) and [VehiclesDB](https://github.com/vehiclesdb/vehiclesdb). Dry-run first:

```sh
bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=/data/vehicles.sqlite
bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=/data/catalog.sqlite VEHICLESDB_ATTRIBUTION_PATH=/data/ATTRIBUTION.md
```

Add `APPLY=true` to persist source records and the canonical make/model/generation/engine hierarchy. Imports are batched and repeatable; they do not download data or change processing runs or knowledge releases. After import, build the PostgreSQL full-text projection with `bin/rails automotive_catalog:rebuild_vehicle_search`.

The import tracks source revision, artifact SHA-256, license and attribution. The VehiclesDB import requires the matching `ATTRIBUTION.md` alongside the artifact (or the environment path shown above) and saves its upstream notices. gor3a's **data** is ODbL 1.0 (attribution to vehicle-makes-models and autoevolution.com; share-alike obligations); VehiclesDB is CC-BY 4.0 and requires its credit plus upstream register notices. Review those terms before distributing a combined/derived database. vPIC standalone downloads are VIN-decoding-only and are not imported as a vehicle taxonomy. This catalog is ACES/PIES-oriented, not certified or conformant; official licensed reference IDs and target-version validation remain separate work.

Vehicle candidate matching uses the locally imported reference catalog only. Candidate model text is kept conservative: specifications and engine terms terminate model extraction, and ambiguous matches must remain unresolved rather than being treated as fitments.

## Documentation

- [Agent manifest](AGENTS.md)
- [Architecture](ARCHITECTURE.md)
- [Roadmap](ROADMAP.md)
- [Current implementation audit](docs/architecture-implementation-audit.md)
- [Detailed ETL architecture plan](docs/automotive-catalog-etl-architecture-plan.md)
