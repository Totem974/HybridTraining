# Public JSON contracts

`v1/*.schema.json` is the only source of truth for the browser boundary. Every
object exposed by the engine is closed with `additionalProperties: false`,
except explicitly opaque option, repetition, execution, issue-details and
snapshot payload maps owned by the Dart engine.

Regenerate TypeScript declarations with `node contracts/generate-types.mjs`.
Validate schemas and fixtures with `python -m pytest contracts/test_contracts.py`.
