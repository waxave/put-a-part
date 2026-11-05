# RFC: Unified, searchable vehicle reference catalog

**Status:** Proposed implementation baseline  
**Date:** 2026-11-05

## Decision

Use the application's PostgreSQL database as the single canonical store. Treat each upstream catalog as an independently versioned input, never as the canonical schema. Preserve every source identity and original record; only link records to one canonical entity when the reconciliation rule is explicit and unambiguous. Keep uncertain matches as reviewable records rather than forcing a merge.

This design is ACES/PIES-oriented, not a claim of conformance. ACES fitment/application and PIES product data remain distinct domains. Official VCdb, PCdb, PAdb, Qdb and Brand Table identifiers and exchange validation require the relevant Auto Care versions and licenses.

## Canonical concepts

| Concept | Canonical representation | Granularity / rule |
|---|---|---|
| Vehicle kind | Controlled value on make/model records (initially car and other kinds as evidenced) | Never infer kind from name alone. |
| Make | `VehicleMake` | One normalized identity only when supported; aliases retain alternate labels. |
| Model/nameplate | `VehicleModel` scoped to make | A nameplate can exist without years or configuration. |
| Model year/configuration | `VehicleConfiguration` | Create only when source evidence supplies a year; configuration properties remain source-backed. |
| Part / brand / classification | Existing `CatalogPart`, `AutomotiveBrand`, `CatalogProductCategory`, `PartIdentifier`, and assertions | Preserve exact part variants; do not conflate classification with fitment. |
| Application / interchange | Evidence-backed assertions and reviewed knowledge | Never derive from co-occurrence, name similarity, or a vehicle catalog. |
| Source identity | Versioned source record and optional canonical links | Multiple source records may link to one entity; one source record must not map to competing canonical entities without review. |

## Ingestion contract

Each adapter maps its input into a common staging contract before reconciliation:

```json
{
  "source_key": "vehiclesdb",
  "source_version": "pinned release or checksum",
  "source_record_id": "stable upstream identifier",
  "record_type": "vehicle_model",
  "raw": {},
  "normalized": {
    "kind": "car",
    "make": "Example",
    "model": "Example model",
    "model_year": null,
    "market": null,
    "attributes": {}
  }
}
```

`raw` is immutable provenance. Normalization is deterministic and versioned. Missing data stays null. Validation issues and conflicting claims are retained, not silently repaired. Import runs are idempotent on `(dataset, source_record_id)` and rerunnable from the same pinned input. Dataset files are supplied locally; imports do not fetch remote data.

## Source treatment

| Input | Initial adapter boundary | Do not infer |
|---|---|---|
| gor3a `vehicles.sqlite` | Read-only SQLite adapter; map only fields present in its actual schema; retain release/checksum and license attribution | Every year in a generation range is a verified configuration; compatibility between engines and trims. |
| VehiclesDB `catalog.sqlite` | Read-only SQLite adapter; map kind, stable IDs, names, aliases, availability and source metadata actually present | Missing years/configurations or part fitment. |
| NHTSA vPIC downloads | Separate VIN-decoding/reference dataset adapter after choosing a specific downloadable artifact and schema | That the standalone database is a complete vehicle taxonomy or ACES VCdb. |

The gor3a adapter is pinned to `ee99776470a45214bf524cdfe22e5dbf4bd67f93`; VehiclesDB is pinned to `d0e40c9661e36931089db1213ac383d2d7ba5a7a` (catalog 2026.10.4). gor3a maps makes/models to canonical make/nameplate rows, its generation and engine hierarchy to separate canonical tables, and retains engine EAV specs in JSONB. VehiclesDB maps kind-scoped make/model identities and retains each availability/popularity row as a versioned source record linked to the canonical model. Neither adapter expands year ranges. NHTSA's standalone vPIC database is intentionally not imported as taxonomy: NHTSA describes it as VIN-decoding-only, and the posted artifacts are SQL Server/PostgreSQL, not SQLite. No source is made distributable merely because its records are stored locally.

## Reconciliation and deduplication

1. Normalize Unicode, whitespace and case for comparison while retaining display labels and raw values.
2. Reuse stable reviewed crosswalks first.
3. Auto-link exact normalized make/model identity only within a compatible vehicle kind and known context; never fuzzy-merge.
4. A model-year record may link to a model without manufacturing engine/trim configurations. Configurations require actual supporting fields and evidence.
5. If source values conflict (kind, market, year, engine, or parent make), retain both source records and flag a conflict for review.
6. Preserve merge decisions and rule version so a later rule change can be audited and reversed.

Uniqueness constraints protect source identities and canonical normalized identities. They do not assert that two semantically similar records are the same vehicle.

## Search

PostgreSQL is the sole search database. Search entries index make/model/accepted aliases and only evidenced configuration terms, with a `simple`-configuration `tsvector` GIN index for automotive tokens and a normalized text index for exact lookup. Search results expose kind, year/configuration granularity, source coverage and unresolved status. Part numbers use exact normalized lookup, not linguistic tokenization. Prefix/trigram search is a later additive extension after query/volume benchmarks.

## Delivery phases

1. **Foundation:** canonical dictionary, dataset/import/source-record provenance, alias/reconciliation status, search index and local-file-only import contract.
2. **Adapters:** gor3a and VehiclesDB SQLite adapters are implemented and fixture-tested; each import records artifact checksum and source revision.
3. **Reconciliation UI/operations:** conflict queue, reviewed crosswalks, reversible merges and import reports.
4. **ACES/PIES exchange:** select licensed standard versions, load licensed reference tables, map internal entities and validate exchange files against those exact schemas.

Migrations are additive. Schema deployment and data imports/backfills are separate operations. Initial import is dry-run by default, batched, safe to retry from the beginning, and does not mutate existing processing runs or knowledge releases. A persisted row-level resume cursor is not implemented yet.

Run `bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=/path/to/catalog.sqlite` or use `SOURCE=gor3a` with `vehicles.sqlite`. The first invocation validates and reports only; use `APPLY=true` to persist. Re-running the same artifact is idempotent and creates a new import-run record while upserting its source identities. Imports never download files. `bin/rails automotive_catalog:rebuild_vehicle_search` atomically refreshes the full-text search projection.

## Open decisions

- Confirm initial market and vehicle kinds.
- Review ODbL share-alike and upstream attribution obligations before distributing gor3a-derived records.
- Identify exact vPIC artifact and intended VIN-decoding use.
- Obtain target ACES/PIES versions and licensed reference data before claiming standards compliance.
