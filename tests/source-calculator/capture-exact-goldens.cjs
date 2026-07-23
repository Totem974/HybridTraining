const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const {
  EXPECTED_SCENARIO_IDS,
  FIXTURE_SET_ID,
  SOURCE_ARCHIVE_SHA256,
  assertExactGoldens,
  corpusSha256,
  outputSha256,
  sha256,
  stableStringify,
} = require('./golden-format.cjs');

const REPOSITORY_ROOT = path.resolve(__dirname, '..', '..');
const FIXTURE_PATH = path.join(
  REPOSITORY_ROOT,
  'test',
  'fixtures',
  'source-calculator-v1',
  'exact-goldens.json',
);
const DEFAULT_ARCHIVE_PATH = 'D:\\GitHub\\scraper\\output\\fivethreeone.app.tar';
const DEFAULT_MIRROR_ROOT =
  'D:\\GitHub\\scraper\\output\\fivethreeone.app\\2026-07-22_15-20-00\\network\\fivethreeone.app';
const SOURCE_URL =
  process.env.SOURCE_CALCULATOR_URL ?? 'http://127.0.0.1:4173/calculator/';
const ARCHIVE_PATH = process.env.SOURCE_CALCULATOR_ARCHIVE ?? DEFAULT_ARCHIVE_PATH;
const MIRROR_ROOT = process.env.SOURCE_CALCULATOR_MIRROR ?? DEFAULT_MIRROR_ROOT;
const WRITE = process.argv.includes('--write');
const ONLY_SCENARIO = process.argv
  .find((argument) => argument.startsWith('--only='))
  ?.slice('--only='.length);

const BASE_INPUT = Object.freeze({
  weightMode: '1 Rep Max',
  unit: 'lbs',
  trainingMaxRatioPercent: 90,
  lifts: {
    'Overhead Press': { reps: 1, weight: 75 },
    'Bench Press': { reps: 1, weight: 100 },
    Squat: { reps: 1, weight: 150 },
    Deadlift: { reps: 1, weight: 200 },
  },
  additionalOptions: {
    warmupOption: '0',
    jokerSets: false,
    deloadAfterCycle: true,
    deloadOption: '0',
    skipWarmup: true,
  },
  scheduling: {
    bastardWorkOrder: false,
    threeFiveOneWeekOrder: false,
  },
  output: {
    programTitle: '',
    printQrCodeWithLink: true,
    showPlating: true,
  },
});

const KG_CHALLENGE_INPUT = Object.freeze({
  ...BASE_INPUT,
  unit: 'kg',
});

const KG_CHALLENGE_TM_PROGRESSION = Object.freeze({
  bbbChallengeTrainingMaxProgression: {
    unit: 'kg',
    upperBodyIncrementKg: 2.5,
    lowerBodyIncrementKg: 5,
    cycleStartWeeks: [1, 4, 8, 11],
    trainingMaxByCycleKg: {
      'Overhead Press': [67.5, 70, 72.5, 75],
      'Bench Press': [90, 92.5, 95, 97.5],
      Squat: [135, 140, 145, 150],
      Deadlift: [180, 185, 190, 195],
    },
  },
});

const GVT_ALTERNATE_SAME_RATIO_ASSERTIONS = Object.freeze({
  gvtAlternateSameRatio: {
    alternateExercise: true,
    useSameRatio: true,
    ratioPercent: 30,
    daysPerWeek: 4,
    supplementalMovementByMain: {
      'Overhead Press': 'Bench Press',
      Deadlift: 'Squat',
      'Bench Press': 'Overhead Press',
      Squat: 'Deadlift',
    },
  },
});

const BBB_CHALLENGE_SAME_LIFT_ASSERTIONS = Object.freeze({
  bbbChallengeSameLift: {
    duration: 'Six Weeks',
    lessBoring: false,
    supplementalExerciseMode: 'sameLift',
    daysPerWeek: 4,
  },
});

const SCENARIOS = Object.freeze([
  scenario('bbb-original-4-day', ['bbb.variant.original', 'schedule.frequency.four'], {
    family: 'Boring But Big',
    selectValues: ['0', '30', '0'],
    checkboxValues: [true],
    days: 4,
  }),
  scenario('bbb-less-boring-4-day', ['bbb.variant.lessBoring'], {
    family: 'Boring But Big',
    selectValues: ['1', '30', '0'],
    checkboxValues: [true],
    days: 4,
  }),
  scenario('bbb-5x5-4-day', ['bbb.variant.fiveByFive'], {
    family: 'Boring But Big',
    selectValues: ['2', '0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('bbb-5x3-4-day', ['bbb.variant.fiveByThree'], {
    family: 'Boring But Big',
    selectValues: ['3', '0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('bbb-5x1-4-day', ['bbb.variant.fiveByOne'], {
    family: 'Boring But Big',
    selectValues: ['4', '0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('bbb-beyond-variation-1-4-day', ['bbb.variant.beyondVariation1'], {
    family: 'Boring But Big',
    selectValues: ['5', '0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('bbb-beyond-variation-2-4-day', ['bbb.variant.beyondVariation2'], {
    family: 'Boring But Big',
    selectValues: ['6', '0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('bbb-2-day', ['bbb.variant.twoDaysPerWeek', 'schedule.frequency.two'], {
    family: 'Boring But Big',
    selectValues: ['7', '0'],
    checkboxValues: [],
    days: 2,
  }),
  scenario('bbb-original-3-day', ['schedule.frequency.three'], {
    family: 'Boring But Big',
    selectValues: ['0', '30', '0'],
    checkboxValues: [true],
    days: 3,
  }),
  scenario('fsl-amrap-4-day', ['fsl.mode.amrap'], {
    family: 'First Set Last',
    selectValues: ['0'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('fsl-multiple-3x5-4-day', ['fsl.mode.multipleSets.3x5'], {
    family: 'First Set Last',
    selectValues: ['1', '3', '5'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('fsl-multiple-5x8-4-day', ['fsl.mode.multipleSets.5x8'], {
    family: 'First Set Last',
    selectValues: ['1', '5', '8'],
    checkboxValues: [],
    days: 4,
  }),
  scenario('gvt-10x10-4-day', ['gvt.10x10'], {
    family: 'GVT',
    selectValues: ['30'],
    checkboxValues: [false, true],
    days: 4,
  }),
  scenario(
    'gvt-10x10-alternate-4-day',
    [
      'gvt.10x10',
      'gvt.alternateExercise.enabled',
      'gvt.useSameRatio.enabled',
    ],
    {
      family: 'GVT',
      selectValues: ['30'],
      checkboxValues: [true, true],
      days: 4,
    },
    BASE_INPUT,
    GVT_ALTERNATE_SAME_RATIO_ASSERTIONS,
  ),
  scenario('bbb-challenge-six-weeks', ['bbbChallenge.duration.sixWeeks'], {
    family: 'BBB Challenge',
    selectValues: ['0'],
    checkboxValues: [true],
    days: 4,
  }),
  scenario(
    'bbb-challenge-six-weeks-same-lift',
    [
      'bbbChallenge.duration.sixWeeks',
      'bbbChallenge.lessBoring.disabled',
    ],
    {
      family: 'BBB Challenge',
      selectValues: ['0'],
      checkboxValues: [false],
      days: 4,
    },
    BASE_INPUT,
    BBB_CHALLENGE_SAME_LIFT_ASSERTIONS,
  ),
  scenario('bbb-challenge-three-months', ['bbbChallenge.duration.threeMonths'], {
    family: 'BBB Challenge',
    selectValues: ['1'],
    checkboxValues: [true],
    days: 4,
  }),
  scenario('bbb-challenge-thirteen-weeks', ['bbbChallenge.duration.thirteenWeeks'], {
    family: 'BBB Challenge',
    selectValues: ['2'],
    checkboxValues: [true],
    days: 4,
  }),
  scenario(
    'bbb-challenge-thirteen-weeks-kg',
    [
      'bbbChallenge.duration.thirteenWeeks',
      'bbbChallenge.tmIncrement.kg.upper2_5',
      'bbbChallenge.tmIncrement.kg.lower5',
    ],
    {
      family: 'BBB Challenge',
      selectValues: ['2'],
      checkboxValues: [true],
      days: 4,
    },
    KG_CHALLENGE_INPUT,
    KG_CHALLENGE_TM_PROGRESSION,
  ),
  scenario('full-body-original-phase-one', ['fullBody.mode.original'], {
    family: 'Full Body',
    selectValues: ['0', '0'],
    checkboxValues: [],
    days: 3,
  }),
  scenario('full-body-updated-default', ['fullBody.mode.updated'], {
    family: 'Full Body',
    selectValues: ['1', '0'],
    checkboxValues: [],
    days: 3,
  }),
  scenario('full-body-full-boring-default', ['fullBody.mode.fullBoring'], {
    family: 'Full Body',
    selectValues: ['2', '0', '0', '0'],
    checkboxValues: [],
    days: 3,
  }),
  scenario('two-day-option-one-deload', ['twoDay.optionOne', 'twoDay.deload.enabled'], {
    family: '2 Days/Week',
    selectValues: ['0'],
    checkboxValues: [],
    days: 2,
  }),
  scenario(
    'two-day-option-one-no-deload',
    ['twoDay.optionOne', 'twoDay.deload.disabled'],
    {
      family: '2 Days/Week',
      selectValues: ['0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { additionalOptions: { deloadAfterCycle: false } },
  ),
  scenario('two-day-option-two-deload', ['twoDay.optionTwo', 'twoDay.deload.enabled'], {
    family: '2 Days/Week',
    selectValues: ['1'],
    checkboxValues: [],
    days: 2,
  }),
  scenario(
    'two-day-option-two-no-deload',
    ['twoDay.optionTwo', 'twoDay.deload.disabled'],
    {
      family: '2 Days/Week',
      selectValues: ['1'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { additionalOptions: { deloadAfterCycle: false } },
  ),
  scenario(
    'two-day-option-three-profile-65-75-85',
    ['twoDay.optionThree', 'twoDay.optionThree.profile.65_75_85'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '0'],
      checkboxValues: [],
      days: 2,
    },
  ),
  scenario(
    'two-day-option-three-profile-70-80-90',
    ['twoDay.optionThree.profile.70_80_90'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '1'],
      checkboxValues: [],
      days: 2,
    },
  ),
  scenario(
    'two-day-option-three-profile-75-85-95',
    ['twoDay.optionThree.profile.75_85_95'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '2'],
      checkboxValues: [],
      days: 2,
    },
  ),
  scenario(
    'two-day-option-three-profile-80-90-100',
    ['twoDay.optionThree.profile.80_90_100'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '3'],
      checkboxValues: [],
      days: 2,
    },
  ),
  scenario(
    'two-day-option-three-no-deload',
    ['twoDay.optionThree', 'twoDay.deload.disabled'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { additionalOptions: { deloadAfterCycle: false } },
  ),
  scenario(
    'two-day-option-one-reordered-pairs',
    ['twoDay.schedule.pairedReordered'],
    {
      family: '2 Days/Week',
      selectValues: ['0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { scheduleOrder: ['Squat', 'Deadlift'] },
  ),
  scenario(
    'two-day-option-three-reordered-lifts',
    ['twoDay.schedule.rotationReordered'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { scheduleOrder: ['Squat', 'Overhead Press', 'Deadlift', 'Bench Press'] },
  ),
  scenario(
    'two-day-option-one-warmup-joker',
    ['twoDay.optionOne.warmupJoker'],
    {
      family: '2 Days/Week',
      selectValues: ['0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { additionalOptions: { jokerSets: true } },
  ),
  scenario(
    'two-day-option-three-deload-two',
    ['twoDay.optionThree.deload2'],
    {
      family: '2 Days/Week',
      selectValues: ['2', '0'],
      checkboxValues: [],
      days: 2,
    },
    BASE_INPUT,
    null,
    { additionalOptions: { deloadOption: '1' } },
  ),
]);

function scenario(
  id,
  coverage,
  template,
  weightInput = BASE_INPUT,
  oracleAssertions = null,
  interactions = {},
) {
  return { id, coverage, template, weightInput, oracleAssertions, interactions };
}

async function main() {
  assertScenarioDefinitionOrder();
  await assertArchiveIntegrity();
  const selectedDefinitions = ONLY_SCENARIO
    ? SCENARIOS.filter((item) => item.id === ONLY_SCENARIO)
    : SCENARIOS;
  if (selectedDefinitions.length === 0) {
    throw new Error(`Unknown --only scenario: ${ONLY_SCENARIO}`);
  }
  if (ONLY_SCENARIO && WRITE) {
    throw new Error('--only and --write cannot be used together');
  }

  const sourceServer = await ensureSourceServer();
  let browser;
  try {
    const { chromium } = loadPlaywright();
    browser = await chromium.launch({ headless: true });
    const scenarios = [];
    for (const definition of selectedDefinitions) {
      process.stdout.write(`Capturing ${definition.id} ... `);
      const captured = await captureScenario(browser, definition);
      scenarios.push(captured);
      process.stdout.write(
        `${captured.output.weekCount} weeks, ${captured.outputSha256.slice(0, 12)}\n`,
      );
    }

    if (ONLY_SCENARIO) {
      const captured = scenarios[0];
      const frozen = JSON.parse(fs.readFileSync(FIXTURE_PATH, 'utf8'));
      assertExactGoldens(frozen);
      const frozenScenario = frozen.scenarios.find(
        (scenario) => scenario.id === captured.id,
      );
      if (!frozenScenario) {
        throw new Error(`Frozen corpus does not contain ${captured.id}`);
      }
      if (stableStringify(frozenScenario) !== stableStringify(captured)) {
        throw new Error(
          `Live source differs from frozen ${captured.id}.\n` +
            `Frozen output: ${frozenScenario.outputSha256}\n` +
            `Live output: ${captured.outputSha256}`,
        );
      }
      process.stdout.write(
        `Live source matches frozen ${captured.id}: ` +
          `${captured.output.weekCount} weeks, ` +
          `${captured.output.weeks.map((week) => week.sessions.length).join('/')} sessions, ` +
          `${captured.outputSha256}.\n`,
      );
      return;
    }

    const document = {
      $schema: 'schemas/exact-goldens.schema.json',
      schemaVersion: 1,
      fixtureSetId: FIXTURE_SET_ID,
      capture: {
        method: 'localBlackBoxChromium',
        sourceEntrypoint: '/calculator/',
        sourceArchiveFileName: path.basename(ARCHIVE_PATH),
        sourceArchiveSha256: SOURCE_ARCHIVE_SHA256,
        sourceReportedVersion: '2.2',
        sourceReportedReleaseDate: '2024-11-20',
        capturedAtUtc: new Date().toISOString(),
        browserName: 'Chromium',
        browserVersion: browser.version(),
        networkPolicy: 'loopbackOnly',
        generatedByHybridTraining: false,
        copiedSourceAssets: false,
        normalization: {
          unicodeWhitespace: 'asciiSpace',
          preserveWeekOrder: true,
          preserveSessionOrder: true,
          preserveExerciseOrder: true,
          preserveSetOrder: true,
          preservePlateOrder: true,
        },
      },
      commonInput: BASE_INPUT,
      scenarioCount: scenarios.length,
      scenarios,
      corpusSha256: corpusSha256(scenarios),
    };
    assertExactGoldens(document);

    if (WRITE) {
      fs.writeFileSync(FIXTURE_PATH, `${JSON.stringify(document, null, 2)}\n`, 'utf8');
      process.stdout.write(`Wrote ${FIXTURE_PATH}\n`);
      return;
    }

    const frozen = JSON.parse(fs.readFileSync(FIXTURE_PATH, 'utf8'));
    assertExactGoldens(frozen);
    compareLiveCapture(frozen, document);
    process.stdout.write(
      `Live source matches ${scenarios.length} frozen exact goldens (${document.corpusSha256}).\n`,
    );
  } finally {
    if (browser) {
      await browser.close();
    }
    if (sourceServer.started) {
      await new Promise((resolve, reject) =>
        sourceServer.server.close((error) => (error ? reject(error) : resolve())),
      );
    }
  }
}

function assertScenarioDefinitionOrder() {
  const actual = SCENARIOS.map((item) => item.id);
  if (stableStringify(actual) !== stableStringify(EXPECTED_SCENARIO_IDS)) {
    throw new Error(
      `Scenario definitions differ from required order.\nExpected: ${EXPECTED_SCENARIO_IDS.join(
        ', ',
      )}\nActual: ${actual.join(', ')}`,
    );
  }
}

async function assertArchiveIntegrity() {
  const bytes = fs.readFileSync(ARCHIVE_PATH);
  const digest = sha256(bytes);
  if (digest !== SOURCE_ARCHIVE_SHA256) {
    throw new Error(
      `Source archive checksum mismatch: expected ${SOURCE_ARCHIVE_SHA256}, got ${digest}`,
    );
  }
}

function loadPlaywright() {
  const modulePath = path.join(
    REPOSITORY_ROOT,
    'apps',
    'web_generator',
    'node_modules',
    '@playwright',
    'test',
  );
  try {
    return require(modulePath);
  } catch (error) {
    throw new Error(
      `Playwright is unavailable at ${modulePath}. Install apps/web_generator dependencies first.`,
      { cause: error },
    );
  }
}

async function ensureSourceServer() {
  if (await sourceLooksHealthy(SOURCE_URL)) {
    return { started: false, server: null };
  }

  const source = new URL(SOURCE_URL);
  if (!isLoopbackHost(source.hostname)) {
    throw new Error(`Refusing to start a mirror for non-loopback URL: ${SOURCE_URL}`);
  }
  const root = path.resolve(MIRROR_ROOT);
  const htmlPath = path.join(root, 'calculator.html');
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`Archived static mirror is missing: ${htmlPath}`);
  }

  const server = http.createServer((request, response) => {
    serveMirrorRequest(root, request, response);
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(Number(source.port || 80), source.hostname, resolve);
  });
  if (!(await sourceLooksHealthy(SOURCE_URL))) {
    await new Promise((resolve) => server.close(resolve));
    throw new Error(`Started mirror did not become healthy at ${SOURCE_URL}`);
  }
  process.stdout.write(`Started archived loopback mirror at ${SOURCE_URL}\n`);
  return { started: true, server };
}

function serveMirrorRequest(root, request, response) {
  const requestUrl = new URL(request.url ?? '/', 'http://127.0.0.1');
  let relativePath = decodeURIComponent(requestUrl.pathname).replace(/^\/+/, '');
  if (relativePath === 'calculator' || relativePath === 'calculator/') {
    relativePath = 'calculator.html';
  }
  const filePath = path.resolve(root, relativePath);
  if (filePath !== root && !filePath.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403);
    response.end('Forbidden');
    return;
  }
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    response.writeHead(404);
    response.end('Not found');
    return;
  }
  response.writeHead(200, { 'Content-Type': contentType(filePath) });
  fs.createReadStream(filePath).pipe(response);
}

function contentType(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case '.html':
      return 'text/html; charset=utf-8';
    case '.js':
      return 'text/javascript; charset=utf-8';
    case '.css':
      return 'text/css; charset=utf-8';
    case '.json':
    case '.webmanifest':
      return 'application/json; charset=utf-8';
    case '.svg':
      return 'image/svg+xml';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.ttf':
      return 'font/ttf';
    default:
      return 'application/octet-stream';
  }
}

function sourceLooksHealthy(url) {
  return new Promise((resolve) => {
    const request = http.get(url, { timeout: 2000 }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => {
        body += chunk;
      });
      response.on('end', () => {
        resolve(response.statusCode === 200 && body.includes('5/3/1 Calculator'));
      });
    });
    request.on('timeout', () => {
      request.destroy();
      resolve(false);
    });
    request.on('error', () => resolve(false));
  });
}

function isLoopbackHost(hostname) {
  return (
    hostname === '127.0.0.1' ||
    hostname === 'localhost' ||
    hostname === '::1' ||
    hostname === '[::1]'
  );
}

async function captureScenario(browser, definition) {
  const context = await browser.newContext({
    locale: 'en-US',
    serviceWorkers: 'block',
    timezoneId: 'UTC',
  });
  const blockedRequests = [];
  const pageErrors = [];
  const allowedOrigin = new URL(SOURCE_URL).origin;
  await context.route('**/*', async (route) => {
    const requestUrl = new URL(route.request().url());
    if (
      requestUrl.origin === allowedOrigin ||
      requestUrl.protocol === 'data:' ||
      requestUrl.protocol === 'blob:'
    ) {
      await route.continue();
      return;
    }
    blockedRequests.push(requestUrl.href);
    await route.abort('blockedbyclient');
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => pageErrors.push(error.message));

  try {
    await page.goto(SOURCE_URL, { waitUntil: 'networkidle' });
    await applyBaseInput(page, definition.weightInput);
    await applyTemplate(page, definition.template);
    const additionalOptions = {
      ...BASE_INPUT.additionalOptions,
      ...(definition.interactions.additionalOptions ?? {}),
    };
    await applyAdditionalOptions(page, additionalOptions);
    await applySchedule(
      page,
      definition.template.days,
      definition.interactions.scheduleOrder,
    );
    await applyOutputOptions(page);
    await page.locator('section.program .container').first().waitFor();
    await page.waitForTimeout(30);

    if (blockedRequests.length > 0) {
      throw new Error(
        `${definition.id} attempted external requests:\n${blockedRequests.join('\n')}`,
      );
    }
    if (pageErrors.length > 0) {
      throw new Error(`${definition.id} emitted page errors:\n${pageErrors.join('\n')}`);
    }

    const selectedState = await extractSelectedState(page);
    if (selectedState.scheduling.daysPerWeek !== definition.template.days) {
      throw new Error(
        `${definition.id}: requested ${definition.template.days} days, UI selected ${selectedState.scheduling.daysPerWeek}`,
      );
    }
    if (
      definition.interactions.scheduleOrder &&
      stableStringify(selectedState.scheduling.liftOrder) !==
        stableStringify(definition.interactions.scheduleOrder)
    ) {
      throw new Error(
        `${definition.id}: requested lift order ${definition.interactions.scheduleOrder.join(
          ', ',
        )}, UI selected ${selectedState.scheduling.liftOrder.join(', ')}`,
      );
    }
    const output = await extractProgram(page);
    const input = {
      commonInputProfile: 'source-v2.2-default-explicit',
      templateFamily: definition.template.family,
      templateSelectValues: definition.template.selectValues,
      templateCheckboxValues: definition.template.checkboxValues,
      daysPerWeek: definition.template.days,
    };
    if (definition.weightInput !== BASE_INPUT) {
      input.weightInputOverride = {
        unit: definition.weightInput.unit,
      };
    }
    if (definition.interactions.additionalOptions) {
      input.additionalOptionsOverride = definition.interactions.additionalOptions;
    }
    if (definition.interactions.scheduleOrder) {
      input.scheduleOrderOverride = definition.interactions.scheduleOrder;
    }
    const captured = {
      id: definition.id,
      coverage: definition.coverage,
      input,
      selectedState,
      output,
      outputSha256: outputSha256(output),
    };
    if (definition.oracleAssertions !== null) {
      captured.oracleAssertions = definition.oracleAssertions;
    }
    return captured;
  } finally {
    await context.close();
  }
}

async function applyBaseInput(page, input) {
  const weight = section(page, 'Weight');
  await weight.getByRole('tab', { name: input.weightMode, exact: true }).click();
  for (const [lift, value] of Object.entries(input.lifts)) {
    await weight.getByLabel(`${lift} reps`, { exact: true }).fill(String(value.reps));
    await weight.getByLabel(`${lift} weight`, { exact: true }).fill(String(value.weight));
  }
  await weight
    .getByLabel('Training Max Ratio', { exact: true })
    .fill(String(input.trainingMaxRatioPercent));
  await weight.getByRole('tab', { name: input.unit, exact: true }).click();
}

async function applyTemplate(page, template) {
  const templateSection = section(page, 'Template');
  await templateSection.locator('select').first().selectOption({ label: template.family });
  for (let index = 0; index < template.selectValues.length; index += 1) {
    const select = templateSection.locator('select').nth(index + 1);
    await select.selectOption(template.selectValues[index]);
  }
  const checkboxes = templateSection.locator('input[type=checkbox]');
  const count = await checkboxes.count();
  if (count !== template.checkboxValues.length) {
    throw new Error(
      `${template.family}: expected ${template.checkboxValues.length} template checkboxes, found ${count}`,
    );
  }
  for (let index = 0; index < template.checkboxValues.length; index += 1) {
    await setCheckbox(checkboxes.nth(index), template.checkboxValues[index]);
  }
}

async function applyAdditionalOptions(page, input) {
  const additional = section(page, 'Additional Options');
  const className = (await additional.getAttribute('class')) ?? '';
  if (className.split(/\s+/).includes('closed')) {
    await additional.getByRole('button', { name: 'Collapse', exact: true }).click();
  }
  const selects = additional.locator('select');
  await selects.first().waitFor();
  await selects.nth(0).selectOption(input.warmupOption);
  await selects.nth(1).selectOption(input.deloadOption);
  const checkboxes = additional.locator('input[type=checkbox]');
  await setCheckbox(checkboxes.nth(0), input.jokerSets);
  await setCheckbox(checkboxes.nth(1), input.deloadAfterCycle);
  if (input.deloadAfterCycle) {
    await setCheckbox(checkboxes.nth(2), input.skipWarmup);
  }
}

async function applySchedule(page, days, desiredOrder) {
  const scheduling = section(page, 'Scheduling');
  const dayTab = scheduling
    .locator('[role=tab]')
    .filter({ hasText: new RegExp(`^${days}$`) });
  if ((await dayTab.count()) > 0) {
    await dayTab.click();
  } else {
    const text = normalizeText(await scheduling.innerText());
    if (!text.includes(`Days a week\n${days}`)) {
      throw new Error(`Scheduling does not expose fixed or selectable ${days}-day cadence`);
    }
  }
  if (desiredOrder) {
    await reorderScheduleByKeyboard(scheduling, desiredOrder);
  }
  const checkboxes = scheduling.locator('input[type=checkbox]');
  await setCheckbox(checkboxes.nth(0), BASE_INPUT.scheduling.bastardWorkOrder);
  await setCheckbox(checkboxes.nth(1), BASE_INPUT.scheduling.threeFiveOneWeekOrder);
}

async function reorderScheduleByKeyboard(scheduling, desiredOrder) {
  const readOrder = () =>
    scheduling.locator('.lift-ordering-lift img').evaluateAll((images) =>
      images.map((image) => image.alt.replace(/\u00a0/g, ' ').trim()),
    );
  const originalOrder = await readOrder();
  if (
    originalOrder.length !== desiredOrder.length ||
    [...originalOrder].sort().join('\n') !== [...desiredOrder].sort().join('\n')
  ) {
    throw new Error(
      `Cannot reorder schedule from [${originalOrder.join(', ')}] to [${desiredOrder.join(
        ', ',
      )}]`,
    );
  }

  for (let targetIndex = 0; targetIndex < desiredOrder.length; targetIndex += 1) {
    const currentOrder = await readOrder();
    const currentIndex = currentOrder.indexOf(desiredOrder[targetIndex]);
    if (currentIndex === -1) {
      throw new Error(`Schedule item disappeared: ${desiredOrder[targetIndex]}`);
    }
    if (currentIndex === targetIndex) continue;

    const draggable = scheduling.locator('.lift-ordering-lift').nth(currentIndex);
    await draggable.focus();
    await draggable.press('Space');
    const direction = currentIndex > targetIndex ? 'ArrowLeft' : 'ArrowRight';
    for (
      let moveIndex = 0;
      moveIndex < Math.abs(currentIndex - targetIndex);
      moveIndex += 1
    ) {
      await draggable.press(direction);
    }
    await draggable.press('Space');
  }

  const finalOrder = await readOrder();
  if (stableStringify(finalOrder) !== stableStringify(desiredOrder)) {
    throw new Error(
      `Keyboard schedule reorder failed: expected [${desiredOrder.join(
        ', ',
      )}], got [${finalOrder.join(', ')}]`,
    );
  }
}

async function applyOutputOptions(page) {
  const output = section(page, 'Output');
  await output.locator('input.title-input').fill(BASE_INPUT.output.programTitle);
  const checkboxes = output.locator('input[type=checkbox]');
  await setCheckbox(checkboxes.nth(0), BASE_INPUT.output.printQrCodeWithLink);
  await setCheckbox(checkboxes.nth(1), BASE_INPUT.output.showPlating);
}

async function setCheckbox(locator, checked) {
  if (checked) {
    await locator.check({ force: true });
  } else {
    await locator.uncheck({ force: true });
  }
}

function section(page, title) {
  return page
    .locator('section')
    .filter({ has: page.locator('h2', { hasText: title }) })
    .first();
}

async function extractSelectedState(page) {
  return page.evaluate(() => {
    const normalize = (value) =>
      (value ?? '').replace(/\u00a0/g, ' ').replace(/[ \t]+/g, ' ').trim();
    const findSection = (title) =>
      [...document.querySelectorAll('section')].find(
        (candidate) => normalize(candidate.querySelector('h2')?.textContent) === title,
      );
    const selectedTab = (root, names) => {
      const selected = [...root.querySelectorAll('[role=tab][aria-selected=true]')].find(
        (candidate) => names.includes(normalize(candidate.textContent)),
      );
      return selected ? normalize(selected.textContent) : null;
    };
    const controlLabel = (element) => {
      const label = element.closest('label');
      if (label) {
        const clone = label.cloneNode(true);
        clone.querySelectorAll('select,input,button,.MuiSwitch-root').forEach((node) =>
          node.remove(),
        );
        const text = normalize(clone.textContent);
        if (text) return text;
      }
      const parentText = normalize(element.parentElement?.parentElement?.innerText);
      return parentText.split('\n')[0] || `control-${element.tagName.toLowerCase()}`;
    };
    const selectState = (root) =>
      [...root.querySelectorAll('select')].map((select, index) => ({
        index,
        label: controlLabel(select),
        value: select.value,
        selectedLabel: normalize(select.selectedOptions[0]?.textContent),
      }));
    const checkboxState = (root) =>
      [...root.querySelectorAll('input[type=checkbox]')].map((input, index) => ({
        index,
        label: controlLabel(input),
        checked: input.checked,
      }));

    const weight = findSection('Weight');
    const template = findSection('Template');
    const additional = findSection('Additional Options');
    const plating = findSection('Plating & Barbell');
    const scheduling = findSection('Scheduling');
    const output = findSection('Output');
    if (!weight || !template || !additional || !plating || !scheduling || !output) {
      throw new Error('One or more source calculator sections are missing');
    }

    const lifts = {};
    for (const weightInput of weight.querySelectorAll('input[aria-label$=" weight"]')) {
      const lift = weightInput.getAttribute('aria-label').replace(/ weight$/, '');
      const reps = weight.querySelector(`input[aria-label="${lift} reps"]`);
      lifts[lift] = {
        reps: Number(reps.value),
        weight: Number(weightInput.value),
      };
    }

    const plateInventory = [...plating.querySelectorAll('.single-picker')].map(
      (picker) => ({
        plate: normalize(picker.querySelector('.plate-icon')?.textContent),
        count: Number(picker.querySelector('input.plate-count')?.value || 0),
      }),
    );
    const barbellInput = plating.querySelector('input[type=number]');
    const selectedDayTab = selectedTab(scheduling, ['2', '3', '4']);
    const fixedDaysMatch = normalize(scheduling.innerText).match(/Days a week\n([234])/);

    return {
      weight: {
        mode: selectedTab(weight, ['1 Rep Max', 'Training Max', '1+ Set']),
        unit: selectedTab(weight, ['lbs', 'kg']),
        trainingMaxRatioPercent: Number(
          weight.querySelector('input[aria-label="Training Max Ratio"]').value,
        ),
        lifts,
      },
      template: {
        selects: selectState(template),
        checkboxes: checkboxState(template),
      },
      additionalOptions: {
        selects: selectState(additional),
        checkboxes: checkboxState(additional),
      },
      plating: {
        plateInventory,
        barbellWeight: Number(barbellInput.value),
      },
      scheduling: {
        daysPerWeek: Number(selectedDayTab ?? fixedDaysMatch?.[1]),
        liftOrder: [...scheduling.querySelectorAll('.lift-ordering-lift img')].map((image) =>
          normalize(image.alt),
        ),
        checkboxes: checkboxState(scheduling),
      },
      output: {
        programTitle: output.querySelector('input.title-input').value,
        checkboxes: checkboxState(output),
      },
    };
  });
}

async function extractProgram(page) {
  const weeks = await page.locator('section.program > .container').evaluate((container) => {
    const normalize = (value) =>
      (value ?? '').replace(/\u00a0/g, ' ').replace(/[ \t]+/g, ' ').trim();
    const result = [];
    const children = [...container.children];
    for (let index = 0; index < children.length; index += 1) {
      const heading = children[index];
      if (heading.tagName !== 'H3') continue;
      const week = children[index + 1];
      if (!week?.classList.contains('week')) {
        throw new Error('A source week heading was not followed by its week table');
      }
      result.push({
        label: normalize(heading.textContent),
        sessions: [...week.querySelectorAll(':scope > .workout')].map(
          (workout, sessionIndex) => {
            const exercises = [];
            let currentExercise = null;
            for (const child of workout.children) {
              if (child.classList.contains('exercise')) {
                currentExercise = { name: normalize(child.textContent), sets: [] };
                exercises.push(currentExercise);
                continue;
              }
              if (child.classList.contains('set')) {
                if (!currentExercise) {
                  throw new Error('A source set appeared before its exercise heading');
                }
                currentExercise.sets.push({
                  work: normalize(child.querySelector('.work')?.textContent),
                  plates: [...child.querySelectorAll('.plate-chip')].map((plate) =>
                    normalize(plate.textContent),
                  ),
                });
              }
            }
            return { position: sessionIndex + 1, exercises };
          },
        ),
      });
    }
    return result;
  });
  return { weekCount: weeks.length, weeks };
}

function normalizeText(value) {
  return value.replace(/\u00a0/g, ' ').replace(/[ \t]+/g, ' ').trim();
}

function compareLiveCapture(frozen, live) {
  const comparableFrozen = {
    commonInput: frozen.commonInput,
    scenarioCount: frozen.scenarioCount,
    scenarios: frozen.scenarios,
    corpusSha256: frozen.corpusSha256,
  };
  const comparableLive = {
    commonInput: live.commonInput,
    scenarioCount: live.scenarioCount,
    scenarios: live.scenarios,
    corpusSha256: live.corpusSha256,
  };
  if (stableStringify(comparableFrozen) !== stableStringify(comparableLive)) {
    throw new Error(
      `Live source outputs differ from frozen goldens.\nFrozen corpus: ${frozen.corpusSha256}\nLive corpus: ${live.corpusSha256}\nRun with --write only after auditing the source archive and the diff.`,
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
