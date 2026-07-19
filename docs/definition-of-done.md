# Core v5 definition of done

Core v5 is ready for product UI only when the four reference plans generate,
round-trip through SQLite, execute all loaded and unloaded activities, advance
their real lifecycle and TM checkpoints, and match stable JSON goldens. Future
amendments must preview and apply atomically without rewriting history.

All migrations and backup versions must preserve data; format, analysis, unit,
widget, coverage, and relevant integration tests must pass; DEV and PROD debug
APKs must build; and the primary scenario must pass on Android 13 or an available
emulator. Active documentation, branch state, and remote branch must be coherent.

The product UI, onboarding, and archived POC design are explicitly outside this
definition. Any unverified source rule stays documentary and forces a not-ready
verdict only if required by the four reference slices.
