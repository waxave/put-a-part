# Current implementation audit

This document summarizes current runtime behavior and known gaps. The older [ETL architecture plan](automotive-catalog-etl-architecture-plan.md) is retained as design history; its API and broader research review/publishing workflow are not current application features.

## Implemented

- Rails UI for workbook upload, run status, records, issues, cancellation, reprocessing and XLSX download. Spanish is the default, with an English switch. The UI has no login; the Sidekiq dashboard uses separate HTTP Basic credentials.
- PostgreSQL-backed run, record, issue, source assertion and vehicle reference persistence, with Active Storage input/output files and Sidekiq processing.
- Two XLSX input profiles: the sample supplier layout and the generic column-mapped `Products` layout.
- Shared parsers for source product attributes, selected engine/specification candidates, vehicle description candidates, references and ring dimensions.
- Six-sheet XLSX export from the checked-in template. The `Atributos` sheet uses the seeded/versioned `attribute_definitions` catalog for Spanish labels and units. Unknown fact types and vehicle candidates are omitted; duplicate values collapse and conflicting values are withheld.
- Local gor3a and VehiclesDB SQLite vehicle-catalog import and PostgreSQL search projection. These provide local reference matching only; they do not establish part fitment.
- Automatic Autofacts v2.3.0 research for eligible rows after extraction; a direct part lookup precedes a delayed search fallback. Findings and extracted fallbacks are applied as candidates before export, and downloads wait for finalization.
- RSpec, Rails tests, RuboCop and configured security checks. CI runs the idempotent test seed before tests; it does not replant the test database.

## Explicitly out of scope

- JSON API endpoints.
- Generalized external provider review and publication workflow beyond the current Autofacts research.
- Claims that candidate facts or local vehicle matches are verified fitments or interchanges.
- Licensed VCdb/PCdb/PAdb datasets and certified ACES/PIES conformance.

Historical records from earlier research workflows are retained; they do not imply that a general review or publication workflow is active.

## Remaining risks and work

1. Broaden extraction and attribute-catalog coverage only against real supplier evidence, with source-specific tests. The current profile/parser set is intentionally limited.
2. Expand workbook contract and golden comparison coverage. The supplied input and output workbooks are different products, not a matching golden pair.
3. Test operational behavior for concurrent workers, retry exhaustion, failures during upload/export and deployment storage durability.
4. Secure unauthenticated UI access and uploaded/downloaded artifacts at the deployment/network boundary. Do not expose it to untrusted networks.
5. Review source licenses and attribution before redistributing imported vehicle data. No official reference data is bundled.

## Migration and data safety

Keep schema migrations separate from data backfills. Preserve existing runs, outputs, observations and knowledge releases; do not rewrite published knowledge or reset databases as part of routine development. For production migrations, plan locks, backups, rollback/forward-fix behavior and deployment ordering for dependent readers.
