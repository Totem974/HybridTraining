# Exact source-calculator goldens

These scripts exercise the archived calculator through local Chromium. They do
not import source application code or copy its assets into HybridTraining.
Browser requests are restricted to the selected loopback origin.

The capture covers:

- all eight Boring But Big variants;
- First Set Last AMRAP, 3x5 and 5x8;
- GVT 10x10 on the main lift and on the alternate lift, both with a common
  30% ratio;
- all three BBB Challenge durations, plus an exact six-week same-lift capture
  with `Less boring` disabled;
- a second 13-week BBB Challenge capture in kg, with exact assertions for the
  +2.5 kg upper-body and +5 kg lower-body training-max increments;
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

Recapture and compare only the kg progression scenario:

```text
node tests/source-calculator/capture-exact-goldens.cjs --only=bbb-challenge-thirteen-weeks-kg
```

Recapture and compare the two explicit template-toggle scenarios:

```text
node tests/source-calculator/capture-exact-goldens.cjs --only=gvt-10x10-alternate-4-day
node tests/source-calculator/capture-exact-goldens.cjs --only=bbb-challenge-six-weeks-same-lift
```

The capture script uses `http://127.0.0.1:4173/calculator/`. If that endpoint is
not available, it starts a temporary static server from the extracted archived
network files and stops it after capture. Override paths only when needed with
`SOURCE_CALCULATOR_URL`, `SOURCE_CALCULATOR_ARCHIVE`, and
`SOURCE_CALCULATOR_MIRROR`.

The GVT assertion checks that the four main lifts are paired with their
alternate lift for ten sets while the single 30% ratio remains selected. The
six-week Challenge assertion checks that disabling `Less boring` keeps the five
supplemental sets on the main lift. The kg Challenge assertion is checked at
cycle starts in weeks 1, 4, 8 and 11.
The verifier derives the expected 5s-week main work from the asserted training
maxes and checks it against the black-box output, while distinguishing the
six-set main-work block from same-name BBB assistance.

Refreshing the immutable fixture is intentionally explicit:

```text
node tests/source-calculator/capture-exact-goldens.cjs --write
```

After a reviewed refresh, update the fixture manifest and raw-byte checksums.
