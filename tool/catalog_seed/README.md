# Catalogue seed staging contract

This directory defines the schema-neutral staging layer for the future SQLite
catalogue import. It is deliberately not connected to runtime persistence.

## Source and identity

`catalog.generated.dart` is the sole input for the initial 354 records. The
catalogue `id` is the idempotency key and must never be replaced by a database
row id.

| Prefix | Generation | Source classification |
| --- | --- | --- |
| `OR-` | original | canonical |
| `BY-` | beyond | canonical |
| `FV-` | forever | canonical |
| `PL-` | original | supplement |

Every import runs as an upsert by catalogue id. Child collections are replaced
atomically from the staged record using deterministic keys:

- source: `(catalogue_id, ordinal)`;
- frequency, level and goal: `(catalogue_id, value)`;
- relationship: `(from_catalogue_id, kind, to_catalogue_id)`;
- engine binding: `(catalogue_id, engine_kind, engine_id)`.

Rows absent from a later seed are not deleted implicitly. Removal requires an
explicit tombstone policy after the database schema is frozen.

## Executability invariant

Only source records already marked `executableTemplate` with a non-null,
registered `generatorId` may be staged as executable. A `NEEDS_REVIEW` reason,
missing generator, ambiguity, or non-executable entry kind can never be
promoted by the importer.

The current source contains 4 executable and 350 non-executable records.

## Neutral manifest contract

The manifest is deeply immutable and carries a version, a deterministic
SHA-256 hash of the complete source, and a deterministic SHA-256 hash for each
record. The hash algorithm and canonicalization version are explicit. Maps are
canonicalized by key and set-derived values are sorted before hashing, so the
same reviewed input produces the same identity independently of a database.

Authority and review are separate structured fields and are never inferred
from `sourceKind`, executability, names, or identifier casing:

- `canonical`, `compatible`, or `userCustom` describes ownership/authority;
- `confirmed`, `needsReview`, or `rejected` describes review state.

Only the four existing legacy generator bindings have an explicit reviewed
attestation in this seed. Every other authority remains `null` with
`needsReview`; this is a publication blocker. Likewise, `stableDomainId` is
`null` for all 354 records pending a reviewed mapping and is never synthesized
by lower-casing the historical `catalogEntryKey`.

Issues also have a typed severity. `isSafeToStage` means safe only for the
physically isolated staging target; it never authorizes import into the runtime
catalogue. It permits documentary and
`needsReview` rows when no validation error exists. `isSafeToPublish` is
stricter and rejects both errors and publication blockers. Missing Cycle v5
bindings, missing licence metadata, and any remaining `needsReview` row are
publication blockers, not reasons to discard source material during staging.

## Relationships and custom data

The generated source has no parent, child, alias or canonical/custom ownership
fields. The staging manifest therefore emits no invented relationships and
reports this absence. Future SQLite imports must:

1. preserve existing custom rows untouched;
2. upsert canonical rows in a separate ownership namespace;
3. preserve existing parent/child/alias edges unless the seed explicitly owns
   and supplies the same edge;
4. reject dangling relationship targets;
5. report missing relationship metadata instead of inferring it from names,
   families, ordering or adjacent identifiers.

## Engine bindings

The four current legacy bindings are preserved verbatim:

- `canonical-beyond`;
- `canonical-bps`;
- `canonical-forever-original-fsl`;
- `canonical-powerlifting`.

Cycle v5 definition and variant bindings are not present in the generated
source. They must be added through an explicit reviewed mapping, not inferred
from labels. Missing bindings are part of the staging report.

## Required preflight and report

Before opening a database transaction, the future adapter must validate:

- exactly 354 unique source ids;
- prefix/generation/source classification consistency;
- source provenance retained in order;
- enum values supported by the frozen database schema;
- generator ids registered and unique where required;
- every non-executable row has a non-empty reason;
- no `NEEDS_REVIEW` row is executable;
- all explicit relationship targets exist;
- all required database fields are either sourced or reported missing.

The transaction is all-or-nothing. Its report must contain inserted, updated,
unchanged and rejected counts, missing-field issues, relationship issues and
engine-binding issues. Re-running the same manifest must produce zero inserted
or updated records.

`catalog_seed_manifest.dart` builds the deterministic neutral manifest and its
preflight report. Once the DB owner freezes the tables, add a separate adapter
from this manifest to those tables; do not put SQL assumptions in the staging
builder.
