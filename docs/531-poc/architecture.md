# Architecture — POC 5/3/1

## Decision

The POC extends the existing Flutter application and Dart Core v5. It does not
introduce a monorepo, React, Vite, a backend, or a second business engine.

```text
lib/features/poc_531/
  catalog/       classified source inventory and coverage
  domain/        pure public POC facade over Core v5
  application/   reversible onboarding/generator state hand-off
  presentation/
    generator/   generator page
    onboarding/  new-user journey
docs/531-poc/    discovery, contracts, rules, tests, and hand-off
tool/531_catalog reproducible catalogue import tooling
```

Existing production behavior remains the default. POC routes are isolated under
`/poc/531`, `/poc/531/generator`, `/poc/531/onboarding`, and
`/poc/531/program/:programId` through minimal app-shell routing.

## Dependency direction

Presentation depends on application state and the pure POC Core facade. The
facade depends on reviewed Core v5 domain models and generation strategies.
Catalogue data is immutable input to the facade. Neither domain nor catalogue
depends on Flutter widgets, browser storage, SQLite, or global UI state.

The onboarding recommendation and generator validation call the same public
Core API. Navigation transfers a versioned `ProgramConfiguration`; it does not
reimplement or reinterpret recommendation rules.

## Determinism and provenance

Generated plans use explicit configuration, stable catalogue IDs, immutable
definitions, versioned schema output, deterministic ordering, and existing
source references. Serialization has a canonical field order and rejects
unknown schema versions. No generator may resolve an unavailable,
documentation-only, or ambiguous entry.

## Catalogue boundary

Every imported source row receives a stable ID, source kind, entry kind,
classification status, provenance, and executability reason. Only reviewed Core
v5 templates with a registered strategy are executable. Classification coverage
and executable coverage are separate metrics.

## Web boundary

Flutter Web is a delivery surface only. Local storage, URL payloads, clipboard,
printing, and downloads are adapters around versioned serialization; they do not
contain training formulas. The POC requires no account, network, database, or
payment flow.

