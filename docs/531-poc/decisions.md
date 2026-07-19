# Decision log

## D-001 — Base the POC on Core v5

Use commit `610b60a` rather than the dirty Android skeleton. This preserves user
changes and reuses the only substantial 5/3/1 engine in the repository.

## D-002 — Flutter Web

Use the repository's Flutter stack. A React/Vite application would add a second
framework and encourage duplicated business logic.

## D-003 — Catalogue completeness is classification completeness

Import and classify all 354 source rows, but expose only reviewed entries with a
registered generator strategy as executable. Missing prescriptions remain
auditable blockers.

## D-004 — Powerlifting is an extension

Powerlifting is never a primary generation, even though one reviewed supplement
template is executable in Core v5.

## D-005 — Isolated routes

Add POC-only routes and preserve the existing validation shell as the default
route. This lifts the temporary UI freeze only for the isolated POC surface.

