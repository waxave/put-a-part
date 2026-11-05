# Architecture

## Current implementation

The repository is a Rails 8.1 application on Ruby 4.0.9 with PostgreSQL, Active Storage, Sidekiq, two XLSX input profiles, shared automotive parsers, a local vehicle reference catalog and template-based XLSX export. Parsers expose `.call` through `Automotive::ServiceBase`. Runs retain source-backed product fields and extracted facts, including explicitly uncertain candidate facts. The exporter edits the checksum-pinned `lib/catalog/output_template.xlsx` with rubyXL to retain its formulas, formatting and filters. The Spanish-default bilingual Rails UI exposes upload, run progress, issues, cancellation, reprocessing and downloads without login; the JSON API is not present. The Sidekiq dashboard is separately protected.

`Atributos` is populated through `attribute_definitions`, seeded with Spanish labels and units and versioned independently from the export schema. Runs pin the attribute catalog version. Only explicitly mapped fact types are exported; unsupported and vehicle facts remain out of this sheet. Duplicate same-value facts collapse; conflicting values are withheld. Description-derived vehicle and specification facts remain candidates, not verified applications or interchanges. The year parser accepts slash/dash two- and four-digit forms with cutoff 30. Local reference import and matching are available, but no licensed VCdb/PCdb/PAdb data or live vehicle-reference API client is bundled. PostgreSQL and Redis are external dependencies; local Active Storage needs shared persistent storage across web and worker processes. Docker/Kamal require deployment-specific configuration. See [README](README.md) and the [implementation audit](docs/architecture-implementation-audit.md) for operations and current gaps.

## Historical proposed target (not current runtime behavior)

The [Automotive Catalog ETL Platform plan](docs/automotive-catalog-etl-architecture-plan.md) records an earlier proposed design. It includes an API and external catalog research/review workflow that are not part of the current application. Use it as design history, not as the source of truth for runtime behavior.

```text
Upload → processing run → supplier profile → shared extraction
       → pinned knowledge resolution → validation → six-sheet XLSX

Authorized sources → observations/evidence → review and reconciliation
                   → immutable knowledge release → future runs
```

### Boundaries

- **Application:** upload, status, records, issues, access control and downloads.
- **ETL core:** orchestration, execution context, validation and export lifecycle.
- **Format profiles:** detection, source layout, mapping and supplier-specific syntax.
- **Domain engine:** reusable facts, parsers, classification and canonical products.
- **Knowledge base:** versioned vocabulary, evidence, assertions and verified relationships.
- **Catalog intelligence:** authorized source selection, retrieval, matching and evidence; independent of export.
- **Exporters:** deterministic logical output, not external search.

### Invariants

- Each run pins its profile, ruleset, export schema and immutable knowledge release; historical runs are not mutated by reprocessing.
- Distinguish observed, candidate, conflicting and verified assertions. Never infer a verified fitment merely from a vehicle configuration or an interchange chain.
- Preserve part variants, source locations and provenance. Unknown data remains unresolved.
- Persist run state and make processing retry-safe; never expose an output before finalization.
- Only use authorized sources and respect their access conditions and licenses.
- Compare workbook content logically; byte-identical XLSX files are not assumed.

The workbook contract is based on supplied fixtures. `input_prueba.xlsx` and `output_prueba.xlsx` represent different products, not a matching input/output pair. The detailed historical proposal documents additional target behavior that remains out of scope.
