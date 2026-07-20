# Hybrid 5/3/1 — Core v5

Hybrid 5/3/1 is a local-first Flutter training engine. The current branch is the
canonical Core v5 rebuild; product UI and onboarding remain intentionally out of
scope. A minimal validation shell exists only to exercise the engine.

## Executable reference plans

- Powerlifting Standard: classic four-week 5/3/1 cycle, including deload.
- Beyond: two three-week cycles with an intervening TM checkpoint, then deload.
- Forever Original + FSL: two Leaders, typed 7th Week Deload, one Anchor, and a
  typed final TM Test.
- Beginner Prep School: three-day A/B sessions with two main movements plus
  executable warm-up, jumps, assistance, and conditioning.

The canonical library also indexes documentary entries. Anything incomplete or
marked `NEEDS_REVIEW` is unavailable and cannot be generated.

## Quality commands

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
.\tool\build_web_release.ps1 -BaseHref "/"
```

For a subdirectory deployment, pass a leading and trailing slash such as
`-BaseHref "/hybrid/"`. See the [Web release contract](docs/531-poc/web-release.md)
for preview, deep-link fallback, Chrome E2E and browser-storage constraints.
`.SOURCE/`, browser drivers, protected assets, personal data and local paths must
never be committed.

## Active documentation

- [Architecture](docs/core-v5-architecture.md)
- [Domain model](docs/core-v5-domain.md)
- [Logical schema](docs/core-v5-schema.md)
- [Canonical catalog](docs/canonical-catalog.md)
- [Rules by generation](docs/generation-rules.md)
- [Lifecycle and amendments](docs/lifecycle-and-amendments.md)
- [Migrations and backups](docs/migrations.md)
- [Definition of done](docs/definition-of-done.md)

Historical audits and superseded specifications are retained under
`docs/archive/legacy-2026-07-19/` and are not active contracts.
