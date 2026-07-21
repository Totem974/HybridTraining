# Catalogue source contract

`catalog_src` is the single editable declarative source for `catalog.db`.
Files are strict, versioned JSON documents. Stable IDs use lower snake case and
are never derived from translated labels. References always include their
catalog revision. Templates reference shared component and schedule IDs rather
than copying their payloads.

Owned source areas:

- `sources/`: the 354-entry classified inventory and canonical references;
- `shared/`, `schedules/`: reusable components and schedules;
- `classic/`, `powerlifting/`, `beyond/`, `forever_cycle/`: Cycle templates;
- `exercises/`, `assistance/`, `conditioning/`: reusable libraries.

Every Cycle variant declares bilingual labels, source rule IDs, one option
schema, one schedule, and a deterministic valid example. Closed option
conditions are `always`, `present`, `equals`, `not`, `all`, `any`, `in`, and
`range`. Placeholders and free-form expressions are invalid.
