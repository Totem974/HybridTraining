# Governed catalog promotion

Promotion is an administration-only, append-only transition from an isolated
staging version **S** to a new normalized `draft` version **N**. It never edits
or consumes S and it never publishes N.

## Reviewed manifest

`ReviewedPromotionManifest` is the sole authority for a promotion plan. It
contains the source and target version identities, timestamps, an explicit
source-key allowlist, and one reviewed disposition per allowlisted source key.
A promoted item supplies every normalized catalog-entry field plus its complete
evidence, declarative rules and aliases. A rejected item supplies an explicit
issue code and prevents apply mode.

The service does not derive stable domain IDs, authority, licence, rules,
aliases, visibility or executability from staging content. No real production
mapping is bundled with the service or its tests.

Promotion of factual rules requires:

- a confirmed normalized entry;
- confirmed entry evidence referencing an existing reviewed source and
  edition, with exact locator and pages;
- schema-v1, confirmed declarative rules with confirmed evidence grouped by
  the same rule ID;
- confirmed aliases whose evidence is explicitly identified;
- `contentReuse: none` on every evidence row: only an original structured
  representation of facts is permitted, never copied text or assets.

`licenseStatus: unknown` does not block factual representation. Licence is not
used as a proxy for factual authority; precise book references and confirmed
review provide that authority. Missing, `needsReview` or mismatched evidence
still fails closed.

## Hashes and simulation

The caller injects the approved hashing implementation. The service
canonicalizes maps by key and computes:

- `planHash`: the complete reviewed plan, compared with `expectedPlanHash`;
- `sourceManifestHash`: read from S and checked against every staged record;
- `sourceRecordHash`: checked for each mapped source entry;
- `normalizedHash`: the complete normalized item;
- `mappingHash`: the source key/hash paired with its normalized hash;
- target content hash: the ordered aggregate of normalized item hashes.

Simulation performs the same reads, validation and report construction as
apply mode without writing. Its report lists promoted, rejected and
non-allowlisted source records with their available hashes and issue codes.

## Atomic apply and idempotence

Apply uses only the typed `CatalogAdministrationDatabase` transaction facade.
Inside one SQLite transaction it creates N as a child `draft`, records a
planned promotion batch, inserts governed entries, evidence, rules, aliases and
promoted audit items, then marks the batch applied. Any failure rolls back N
and every audit/content row together.

An already-applied promotion is found by the pair
`(sourceManifestHash, targetContentHash)`. Reapplying the identical reviewed
plan returns the existing target and does not duplicate rows. S, its staging
entries and its blockers remain unchanged in every mode.
