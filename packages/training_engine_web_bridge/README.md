# training_engine_web_bridge

Thin, JSON-only browser bridge. It uses `dart:js_interop`, `@JSExport`,
`Function.toJS`-compatible exports and `createJSInteropWrapper`; it has no DOM,
storage, localization or training logic.

## Lead integration point

Replace `createTrainingEngineBindings()` in `web/main.dart` with the adapter to
the final `training_engine` v1 codecs. The adapter must reject unknown keys and
return canonical envelopes conforming to `contracts/v1`.

Build with:

```text
dart compile js -O2 web/main.dart -o build/training_engine_bridge.js
```
