# Web release contract

This contract produces a static, host-agnostic Flutter Web release. It does not
publish files or assume a hosting provider.

## Build and preview

From the repository root:

```powershell
.\tool\build_web_release.ps1 -BaseHref "/"
```

For a site mounted at `https://example.test/hybrid/`, build with
`-BaseHref "/hybrid/"`. The value must start and end with `/`. The PWA manifest
uses relative `start_url` and `scope`, so it follows that deployment base instead
of forcing the origin root. Deploy the contents of `build/web`.

The host must serve `index.html` for unknown paths below the deployment base.
Without this SPA fallback, direct navigation or refresh on `/poc/531`,
`/poc/531/generator`, or `/poc/531/program/<program-id>` returns a host-level
404. The checked-in preview implements the fallback:

```powershell
.\tool\preview_web.ps1 -Port 8080 -BasePath "/"
```

For a `/hybrid/` build, pass `-BasePath "/hybrid/"` and open
`http://127.0.0.1:8080/hybrid/`. Stop it with Ctrl+C.

## Chrome end-to-end test

Install Google Chrome and the official ChromeDriver with the same major version.
Keep the driver outside the repository, then run:

```powershell
.\tool\run_chrome_e2e.ps1 `
  -DriverPath "C:\path\outside\repo\chromedriver.exe" `
  -DriverPort 4444 `
  -WebPort 7357
```

The script prints the driver version, rejects a busy driver port, starts and
stops the driver, applies a short timeout, and runs the checked-in calculator
flow through Flutter's `web-server` device. `-ChromeExecutable` can select a
non-default Chrome binary. No browser, driver, generated release, or local path
is part of the repository contract.

## Local data and transfer

The Web POC stores Forever series snapshots in browser `localStorage`. Web
storage is scoped to the complete origin (scheme, host and port), not merely the
route or base path. Changing origin, clearing site data, private browsing, or
using another browser/profile makes saved series unavailable. Production should
therefore use a stable origin.

Exported JSON is the explicit portable hand-off. Save exports before changing
origin or clearing browser storage, and validate imports before applying them.
The release directory itself contains no user data.

## POC limits

- Web persistence uses `localStorage`; SQLite belongs to the non-Web application
  and is not claimed by this release.
- Android builds and validation are deferred to a later chantier.
- Chrome is the reference browser. Firefox has prior recorded validation but is
  not run by this contract. Edge remains blocked by the Flutter 3.44.6 WebDriver
  capability mismatch and is not a release gate.
- The preview is a local validation utility, not a production server.

Before delivery, run dependency resolution, formatting, analysis, the full test
suite, the release build, and Chrome E2E. Record only results from the current
revision; historical counts in `testing.md` are not live gates.

Current local validation: 383 tests pass, static analysis reports no issue, and
release builds succeed for both `/` and `/hybrid/`. Chrome 150.0.7871.129 with
ChromeDriver 150.0.7871.124 passes the five checked-in scenarios in 35.4
seconds.
