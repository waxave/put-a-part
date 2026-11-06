# Roadmap

This roadmap tracks the current application, not the historical milestones in the [proposed architecture plan](docs/automotive-catalog-etl-architecture-plan.md). The plan is not a commitment to build every proposed subsystem. Current boundaries and behavior are in [ARCHITECTURE.md](ARCHITECTURE.md).

## Backlog

- Broaden attribute catalog and extraction coverage using validated supplier evidence.
- Add supplier formats and product families when supported by real input samples and regression fixtures.
- Harden single-user deployment, artifact protection, worker reliability and operational monitoring.
- Continue local vehicle reference catalog improvements; do not imply verified part fitments from vehicle reference matching.

## Current implementation

- Workbook upload, queued processing, progress, issues, cancellation, reprocessing and download are implemented in the Spanish-default bilingual Rails UI. The UI has no login; Sidekiq dashboard access is separately protected.
- Two XLSX profiles share extraction and export code: the sample supplier layout and a generic column-mapped `Products` layout.
- Exports use the template's six sheets. Attribute labels, classes and units come from the versioned Spanish `attribute_definitions` catalog. Unsupported facts and vehicle candidates are not emitted in `Atributos`.
- Local vehicle reference imports and matching are available, but do not verify product fitments.
- Automatic Autofacts v2.3.0 part research runs after extraction and before export, with results retained as unverified candidates. The JSON API and broader review/publishing workflow are not part of current runtime behavior.

See [the implementation audit](docs/architecture-implementation-audit.md) for current gaps and constraints.

## Completed

- Rails application scaffold generated.
