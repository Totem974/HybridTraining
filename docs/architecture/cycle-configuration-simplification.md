# Cycle configuration simplification

## Decision

HybridTraining keeps three separate responsibilities:

```text
catalog.db   immutable published definitions
workspace    editable CycleConfiguration documents
training.db  generated snapshots and performed training
```

The simplification targets the workspace and Web editor. It does not merge the
catalogue with user data and does not move training rules into the UI.

## Source inspiration

The locally captured calculator demonstrates a useful interaction model:

```text
one complete form document
→ regenerate after every change
→ persist locally
→ project only active template options into a shareable URL
```

HybridTraining adopts that model but rejects label-based identities, numeric
variant indexes, template switches in presentation code, and training formulas
embedded in UI components.

## Canonical workspace document

`CycleConfiguration` is the only editable, persisted and exchanged Cycle
document. It contains:

- stable template and variant IDs;
- only the selected template's specific options;
- common Warm-up, Joker and Deload options;
- maximum inputs, schedule, equipment and output preferences;
- an explicit configuration version and catalogue identity.

`CycleRequest` remains the strict execution contract. A single adapter converts
the canonical configuration into a request; the compiler never consumes Web
editor state.

```text
CycleEditorSchema + CycleConfiguration
→ generic path intents
→ normalize and validate
→ CycleRequest
→ CycleCompiler
→ GeneratedCycle
```

## Invariants

1. The Web UI contains no template ID switch and no training formula.
2. Unknown configuration keys are rejected.
3. Weights use integer centi-units and an explicit unit.
4. Inactive template options are not persisted in the portable document.
5. Old drafts and imports are migrated explicitly and are never deleted merely
   because the engine or catalogue version changed.
6. Generated snapshots remain separate from their source configuration.
7. Catalogue aliases resolve migrations; presentation code does not.
8. Defaults originate from the catalogue/editor schema and generate a valid
   program immediately.

## Migration stages

1. Introduce and validate `CycleConfiguration` v1.
2. Add pure codecs between editor values, configuration and `CycleRequest`.
3. Migrate IndexedDB drafts additively while preserving incompatible records.
4. Make the Web store, import and export the canonical document.
5. Move normalization and request projection behind the engine bridge.
6. Add a canonical compressed URL projection and ordered migrations.

The relational catalogue and the `training.db` snapshot projections remain
unchanged during these stages.
