# Static Cycle generator

`/cycle/` is a framework-free, static multi-page Vite application. It loads
the versioned catalog bundle from the same origin and calls the Dart engine
compiled to JavaScript through `globalThis.hybridTrainingEngine`.

There is no application server or business HTTP API. Runtime data stays in
the browser through IndexedDB; only locale, collapsed sections and the plating
display preference may use localStorage.

## Reproducible build

From this directory:

```text
npm ci
npm run typecheck
npm test
npm run build
npm run e2e
```

The catalog and engine artifacts are generated from the repository root:

```text
npm run catalog:build:web
npm run engine:build
npm run verify:parity
```

`dist/` is fully static. Keep the existing Flutter Web build available until
the documented visual comparison and cutover approval have been completed.
