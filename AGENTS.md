# Project Manifest: Put a Part

## Current stack

- Ruby 4.0.9; Rails 8.1; Bundler; PostgreSQL.
- Rails Active Job with Sidekiq/Redis; Solid Cache and Solid Cable; local Active Storage configuration.
- Minitest and RSpec, Roo, RuboCop, Brakeman, bundler-audit, importmap audit; Docker and generated Kamal configuration.
- Hotwire (Turbo and Stimulus), import maps, Propshaft, Puma.

The current application is a Spanish-default workbook processing UI with two XLSX input profiles, database-backed Spanish attribute definitions, candidate extraction, automatic Autofacts v2.3.0 research enqueueing after upload/reprocessing, and six-sheet export. Candidate vehicle/specification facts and external Autofacts claims are not verified fitments or interchanges. Current behavior is documented in [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md); the detailed ETL plan is historical/proposed and is not an implementation contract.

## Commands

- `bin/setup --skip-server` — install dependencies and prepare the database; also clears logs and temporary files.
- `bin/dev` — start the development application and Sidekiq worker together; configure PostgreSQL, Redis and Sidekiq dashboard credentials as in README.
- `bundle exec sidekiq -C config/sidekiq.yml` — start a background worker separately if Rails was started independently.
- `bin/rails test` — run current tests; `bin/rails test:system` runs system tests.
- `bundle exec rspec` — run RSpec specs, including workbook contracts, export and pipeline coverage.
- `bin/rubocop` — check Ruby style.
- `bin/ci` — run configured setup, checks, seed loading and tests. Inspect `config/ci.rb` before assuming any database operation is non-destructive.
- `bin/rails routes` — inspect routes.

## Project rules

- Follow Rails conventions and the existing code style; keep domain extraction separate from supplier layout and external connectors.
- Follow current behavior and boundaries in [ARCHITECTURE.md](ARCHITECTURE.md). Treat `docs/automotive-catalog-etl-architecture-plan.md` as a historical proposal only. Record unresolved facts; never fabricate verified fitment or interchange.
- Pin versions for reproducible exports. Do not use live external lookups during export or alter published knowledge releases.
- Access external data only when authorized, respecting licenses, access controls and rate limits.
- Protect uploads, run data and downloads. The UI has no login; do not expose it or its artifacts to untrusted networks.
- Add RSpec tests for new behavior; the existing Rails test setup remains in place.
- Never mix a schema migration and data backfill; plan production-safe migrations.
- Preserve existing documentation and untracked user work. Avoid destructive database operations without explicit authorization.

## Documentation map

- [README](README.md): setup and overview.
- [Architecture](ARCHITECTURE.md): current system boundaries and invariants, followed by a clearly labeled historical target.
- [Roadmap](ROADMAP.md): delivery status.
- [Detailed architecture plan](docs/automotive-catalog-etl-architecture-plan.md): historical proposal; the API and broader review/publishing workflow are not current behavior.
- `docs/decisions/`, `docs/rfcs/`, `docs/features/`, `docs/fixes/`, `docs/refactors/`, `docs/chores/`, `docs/spikes/`, `docs/runbooks/`, and `docs/diagrams/`: topic-specific records.

## Branch conventions

Use descriptive, short names: `feature/<topic>`, `fix/<topic>`, `refactor/<topic>`, `chore/<topic>`, or `spike/<topic>`. Do not create or switch branches without instruction.

## Available Skills

<!-- Managed by /sync-skills:start -->
| Skill | Category | Description |
|---|---|---|
| adr-generation | documentation | Generate architecture decision records. |
| architecture-analysis | architecture | Analyze architecture, boundaries, dependencies and drift. |
| commit-grouping | git | Group changes into atomic commits. |
| conventional-commits | git | Generate Conventional Commit messages. |
| git-analysis | git | Analyze status, diffs, branches and history. |
| graph-linking | memory | Link related vault concepts. |
| pr-generation | git | Generate pull request descriptions and checklists. |
| project-documentation | documentation | Maintain project documentation. |
| rfc-generation | documentation | Generate technical and product RFCs. |
| vault-sync | memory | Sync project knowledge to the vault. |
| work-chore | workflow | Manage maintenance work. |
| work-feature | workflow | Manage feature work. |
| work-fix | workflow | Manage bug fixes. |
| work-refactor | workflow | Manage refactors. |
| work-spike | workflow | Manage research spikes. |
<!-- Managed by /sync-skills:end -->

Skills are discoverable capabilities, not automatically loaded context. Project-local skills in `.agents/skills/` may also be available through the agent harness.
