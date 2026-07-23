# Exact source-calculator goldens

These scripts exercise the archived calculator through local Chromium. They do
not import source application code or copy its assets into HybridTraining.
Browser requests are restricted to the selected loopback origin.

The capture covers:

- all eight Boring But Big variants;
- First Set Last AMRAP, 3x5 and 5x8;
- GVT 10x10;
- all three BBB Challenge durations;
- the three Full Body modes;
- two-, three- and four-day schedules.

Verify the frozen corpus without launching a browser:

```text
node tests/source-calculator/verify-exact-goldens.cjs
```

Compare the frozen corpus with a fresh run of the local mirror:

```text
node tests/source-calculator/capture-exact-goldens.cjs
```

The capture script uses `http://127.0.0.1:4173/calculator/`. If that endpoint is
not available, it starts a temporary static server from the extracted archived
network files and stops it after capture. Override paths only when needed with
`SOURCE_CALCULATOR_URL`, `SOURCE_CALCULATOR_ARCHIVE`, and
`SOURCE_CALCULATOR_MIRROR`.

Refreshing the immutable fixture is intentionally explicit:

```text
node tests/source-calculator/capture-exact-goldens.cjs --write
```

After a reviewed refresh, update the fixture manifest and raw-byte checksums.
