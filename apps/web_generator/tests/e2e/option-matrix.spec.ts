import { expect, test, type Download, type Locator, type Page } from '@playwright/test';
import { readFile } from 'node:fs/promises';

const localOrigin = 'http://127.0.0.1:4175';

interface GeneratedCycle {
  readonly templateId: string;
  readonly variantId: string;
  readonly weeks: readonly {
    readonly sessions: readonly {
      readonly movementId: string;
      readonly blocks: readonly {
        readonly id: string;
        readonly role: string;
        readonly movementId: string;
        readonly sets: readonly {
          readonly repetitions: Readonly<Record<string, unknown>>;
          readonly percentageBasisPoints?: number | null;
          readonly plannedLoad?: {
            readonly centiUnits: number;
            readonly unit: 'kg' | 'lb';
          } | null;
        }[];
      }[];
    }[];
  }[];
}

type GeneratedBlock =
  GeneratedCycle['weeks'][number]['sessions'][number]['blocks'][number];

async function openCycle(page: Page): Promise<string[]> {
  const external: string[] = [];
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    if (url.origin !== localOrigin) {
      external.push(url.href);
      await route.abort('blockedbyclient');
    } else {
      await route.continue();
    }
  });
  await page.goto('/cycle/');
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/week 1|semaine 1/i);
  await installRequestRecorder(page);
  return external;
}

async function installRequestRecorder(page: Page): Promise<void> {
  await page.evaluate(() => {
    if (document.documentElement.dataset.cycleRequestRecorder === 'true') return;
    const engine = window.hybridTrainingEngine;
    if (!engine) throw new Error('ENGINE_BRIDGE_UNAVAILABLE');
    const generateCycle = engine.generateCycle.bind(engine);
    engine.generateCycle = (requestJson: string) => {
      document.documentElement.dataset.lastCycleRequest = requestJson;
      return generateCycle(requestJson);
    };
    document.documentElement.dataset.cycleRequestRecorder = 'true';
  });
}

async function optionIds(select: Locator): Promise<string[]> {
  const values = await select.locator('option').evaluateAll((items) =>
    items.map((item) => (item as HTMLOptionElement).value),
  );
  return values.map((value) => {
    const id = JSON.parse(value) as unknown;
    if (typeof id !== 'string') throw new Error(`NON_STRING_CATALOG_ID:${value}`);
    return id;
  });
}

async function chooseCatalogVariant(
  page: Page,
  generationId: string,
  templateId: string,
  variantId: string,
): Promise<void> {
  const generation = page.getByTestId('generation-row').getByRole('combobox');
  const template = page.getByTestId('template-row').getByRole('combobox');
  const variant = page.getByTestId('variant-row').getByRole('combobox');

  await generation.selectOption(JSON.stringify(generationId));
  await expect.poll(() => optionIds(template)).toContain(templateId);
  await template.selectOption(JSON.stringify(templateId));
  await expect.poll(() => optionIds(variant)).toContain(variantId);
  await variant.selectOption(JSON.stringify(variantId));
  await expect.poll(async () => {
    const request = await lastCycleRequest(page);
    return [request?.templateId, request?.variantId];
  }).toEqual([templateId, variantId]);
}

async function lastCycleRequest(
  page: Page,
): Promise<Record<string, unknown> | undefined> {
  const raw = await page.locator('html').getAttribute('data-last-cycle-request');
  return raw ? JSON.parse(raw) as Record<string, unknown> : undefined;
}

async function chooseSchedule(page: Page, scheduleId: string): Promise<void> {
  const controls = page.locator(
    '[data-cycle-region="scheduling"] input[type="radio"][name="scheduleId"]',
  );
  await expect.poll(async () =>
    controls.evaluateAll((items) =>
      items.map((item) => JSON.parse((item as HTMLInputElement).value) as unknown)
    )
  ).toContain(scheduleId);
  const values = await controls.evaluateAll((items) =>
    items.map((item) => JSON.parse((item as HTMLInputElement).value) as unknown),
  );
  const index = values.indexOf(scheduleId);
  if (index < 0) throw new Error(`SCHEDULE_CONTROL_MISSING:${scheduleId}`);
  await controls.nth(index).check();
  await expect.poll(async () => (await lastCycleRequest(page))?.scheduleId).toBe(
    scheduleId,
  );
}

async function chooseTemplate(page: Page, label: string): Promise<void> {
  await page.getByTestId('template-row').getByRole('combobox').selectOption({ label });
}

async function chooseVariant(page: Page, label: string): Promise<void> {
  await page.getByTestId('variant-row').getByRole('combobox').selectOption({ label });
}

async function setChoice(control: Locator, value: string | number): Promise<void> {
  const tag = await control.evaluate((element) => element.tagName.toLowerCase());
  if (tag === 'select') await control.selectOption(JSON.stringify(value));
  else await control.fill(String(value));
  await control.blur();
}

async function setSwitch(page: Page, testId: string, checked: boolean): Promise<void> {
  const control = page.getByTestId(testId);
  if (checked) await control.check();
  else await control.uncheck();
}

async function downloadArtifact(page: Page, name: RegExp): Promise<Record<string, unknown>> {
  const pending = page.waitForEvent('download');
  await page.getByRole('button', { name }).click();
  return readDownload(await pending);
}

async function readDownload(download: Download): Promise<Record<string, unknown>> {
  const path = await download.path();
  if (!path) throw new Error('DOWNLOAD_PATH_MISSING');
  return JSON.parse(await readFile(path, 'utf8')) as Record<string, unknown>;
}

async function configuration(page: Page): Promise<Record<string, unknown>> {
  return downloadArtifact(page, /export.*configuration|exporter.*configuration/i);
}

async function generatedCycle(page: Page): Promise<GeneratedCycle> {
  const artifact = await downloadArtifact(
    page,
    /export.*program|exporter.*programme/i,
  );
  const response = payload(artifact) as { readonly cycle?: GeneratedCycle };
  if (!response.cycle) throw new Error('EXPORTED_CYCLE_MISSING');
  return response.cycle;
}

async function programFingerprint(page: Page): Promise<string> {
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/week 1|semaine 1/i);
  // Generation is debounced. Let the bridge publish the response belonging to
  // the option change before downloading the program snapshot.
  await page.waitForTimeout(200);
  const artifact = await downloadArtifact(page, /export.*program|exporter.*programme/i);
  const payload = artifact.payload as Record<string, unknown>;
  const cycle = (payload.cycle ?? payload) as Record<string, unknown>;
  return JSON.stringify(cycle.weeks);
}

function payload(artifact: Record<string, unknown>): Record<string, unknown> {
  return artifact.payload as Record<string, unknown>;
}

function commonOptions(artifact: Record<string, unknown>): Record<string, unknown> {
  return payload(artifact).commonOptions as Record<string, unknown>;
}

test('Full Body Original phases are distinct while Updated and Full Boring expose no phase', async ({ page }) => {
  const external = await openCycle(page);
  await chooseTemplate(page, 'Full Body');
  await chooseVariant(page, 'Original');
  const engineFieldIds = await page.evaluate(() => {
    const schema = JSON.parse(window.hybridTrainingEngine!.cycleEditorSchema(
      JSON.stringify({
        apiVersion: 'v1',
        schemaVersion: 1,
        templateId: 'classic_full_body',
        variantId: 'original',
      }),
    )) as { fields: Array<{ id: string }> };
    return schema.fields.map((field) => field.id);
  });
  expect(engineFieldIds).toContain('phase');
  await expect(page.getByTestId('phase')).toBeVisible();

  const phaseOutputs = new Set<string>();
  for (const phase of ['phase_one', 'phase_two', 'phase_three']) {
    await setChoice(page.getByTestId('phase'), phase);
    phaseOutputs.add(await programFingerprint(page));
  }
  expect(phaseOutputs.size).toBe(3);

  await chooseVariant(page, 'Updated');
  await expect(page.getByTestId('phase')).toHaveCount(0);
  await expect(page.getByTestId('squat_set_profile')).toBeVisible();
  const updated = await programFingerprint(page);

  await chooseVariant(page, 'Full Boring');
  await expect(page.getByTestId('phase')).toHaveCount(0);
  await expect(page.getByTestId('squat_set_profile')).toBeVisible();
  await expect(page.getByTestId('bench_set_profile')).toBeVisible();
  await expect(page.getByTestId('deadlift_set_profile')).toBeVisible();
  expect(await programFingerprint(page)).not.toBe(updated);
  expect(external).toEqual([]);
});

test('legacy Full Body ID imports as canonical Original plus phase', async ({ page }) => {
  const external = await openCycle(page);
  const exported = await configuration(page);
  const configurationPayload = payload(exported);
  const maxes = configurationPayload.maxes as Record<string, unknown>;
  const schedule = configurationPayload.schedule as Record<string, unknown>;
  const equipment = configurationPayload.equipment as Record<string, unknown>;
  const output = configurationPayload.output as Record<string, unknown>;
  const request: Record<string, unknown> = {
    apiVersion: 'v1',
    schemaVersion: 1,
    cycleId: 'legacy-full-body',
    templateId: 'classic_full_body_phase_2',
    variantId: 'phase_2',
    scheduleId: schedule.id,
    startDate: schedule.startDate,
    sessionOrder: schedule.sessionOrder,
    maxInputs: Object.fromEntries(Object.entries(maxes.values as Record<string, object>)
      .map(([movement, input]) => [movement, { type: maxes.mode, ...input }])),
    globalTrainingMaxRatioBasisPoints: maxes.globalTrainingMaxRatioBasisPoints,
    options: {},
    unit: equipment.unit,
    barProfile: equipment.bar,
    includeDeload: false,
    programTitle: output.title,
    showPlating: output.showPlating,
  };
  exported.payload = request;
  await page.locator('input[type="file"]').setInputFiles({
    name: 'legacy-full-body.json',
    mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify(exported)),
  });
  await expect(page.getByTestId('template-row').getByRole('combobox')).toHaveValue(
    JSON.stringify('classic_full_body'),
  );
  await expect(page.getByTestId('variant-row').getByRole('combobox')).toHaveValue(
    JSON.stringify('original'),
  );
  await expect(page.getByTestId('phase')).toHaveValue(JSON.stringify('phase_two'));
  expect(external).toEqual([]);
});

test('configuration import restores nested non-default options', async ({ page }) => {
  await openCycle(page);
  await setSwitch(page, 'warmUp.enabled', true);
  await setChoice(page.getByTestId('warmUp.type'), 'beyond');
  await page.getByTestId('warmUp.bases.lowerBody').fill('142');
  await page.getByTestId('warmUp.bases.upperBody').fill('102');
  await setSwitch(page, 'joker.enabled', true);
  await setChoice(page.getByTestId('joker.ceilingBasisPoints'), 3000);
  await setSwitch(page, 'deload.enabled', true);
  await setChoice(page.getByTestId('deload.type'), 'deload5');
  await setSwitch(page, 'deload.skipWarmUp', true);
  const exported = await configuration(page);

  await setSwitch(page, 'warmUp.enabled', false);
  await setSwitch(page, 'joker.enabled', false);
  await setSwitch(page, 'deload.enabled', false);
  await page.locator('input[type="file"]').setInputFiles({
    name: 'nested-options.json',
    mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify(exported)),
  });

  await expect(page.getByTestId('warmUp.enabled')).toBeChecked();
  await expect(page.getByTestId('warmUp.type')).toHaveValue(JSON.stringify('beyond'));
  await expect(page.getByTestId('warmUp.bases.lowerBody')).toHaveValue('142');
  await expect(page.getByTestId('warmUp.bases.upperBody')).toHaveValue('102');
  await expect(page.getByTestId('joker.enabled')).toBeChecked();
  await expect(page.getByTestId('joker.ceilingBasisPoints')).toHaveValue(JSON.stringify(3000));
  await expect(page.getByTestId('deload.type')).toHaveValue(JSON.stringify('deload5'));
  await expect(page.getByTestId('deload.skipWarmUp')).toBeChecked();
});

test('Beyond warm-up toggles conditional bases and preserves numeric defaults across kg/lb', async ({ page }) => {
  const external = await openCycle(page);
  await setSwitch(page, 'warmUp.enabled', true);
  await setChoice(page.getByTestId('warmUp.type'), 'original');
  await expect(page.getByTestId('warmUp.bases.lowerBody')).toHaveCount(0);
  await expect(page.getByTestId('warmUp.bases.upperBody')).toHaveCount(0);

  await setChoice(page.getByTestId('warmUp.type'), 'beyond');
  await expect(page.getByTestId('warmUp.bases.lowerBody')).toBeVisible();
  await expect(page.getByTestId('warmUp.bases.upperBody')).toBeVisible();

  await page.getByRole('radio', { name: /^lb$/i }).check();
  let options = commonOptions(await configuration(page));
  let warmUp = options.warmUp as Record<string, unknown>;
  let bases = warmUp.bases as Record<string, Record<string, unknown>>;
  expect(bases.lowerBody).toMatchObject({ centiUnits: 13500, unit: 'lb' });
  expect(bases.upperBody).toMatchObject({ centiUnits: 9500, unit: 'lb' });

  await page.getByRole('radio', { name: /^kg$/i }).check();
  options = commonOptions(await configuration(page));
  warmUp = options.warmUp as Record<string, unknown>;
  bases = warmUp.bases as Record<string, Record<string, unknown>>;
  expect(bases.lowerBody).toMatchObject({ centiUnits: 13500, unit: 'kg' });
  expect(bases.upperBody).toMatchObject({ centiUnits: 9500, unit: 'kg' });

  await setSwitch(page, 'warmUp.enabled', false);
  options = commonOptions(await configuration(page));
  expect(options.warmUp).toEqual({ enabled: false });
  expect(external).toEqual([]);
});

test('Joker off and every +5 through +30 ceiling produce distinct bridge output', async ({ page }) => {
  test.slow();
  const external = await openCycle(page);
  await setSwitch(page, 'joker.enabled', false);
  const outputs = new Set<string>([await programFingerprint(page)]);
  await setSwitch(page, 'joker.enabled', true);
  for (const ceiling of [500, 1000, 1500, 2000, 2500, 3000]) {
    await setChoice(page.getByTestId('joker.ceilingBasisPoints'), ceiling);
    outputs.add(await programFingerprint(page));
  }
  expect(outputs.size).toBe(7);
  expect(external).toEqual([]);
});

test('deload matrix covers off, 1..5 skip transitions and High Intensity exclusion', async ({ page }) => {
  test.slow();
  const external = await openCycle(page);
  await setSwitch(page, 'warmUp.enabled', true);
  await setChoice(page.getByTestId('warmUp.type'), 'original');

  await setSwitch(page, 'deload.enabled', false);
  const offFingerprint = await programFingerprint(page);
  await expect(page.locator('.program-week')).toHaveCount(3);
  const fingerprints = new Map<string, string>([['off', offFingerprint]]);
  const outputs = new Set<string>([offFingerprint]);
  let options = commonOptions(await configuration(page));
  expect(options.deload).toEqual({ enabled: false });

  await setSwitch(page, 'deload.enabled', true);
  await expect(page.locator('.program-week')).toHaveCount(4);
  for (const type of ['deload1', 'deload2', 'deload3', 'deload4', 'deload5']) {
    await setChoice(page.getByTestId('deload.type'), type);
    await expect(page.getByTestId('deload.skipWarmUp')).toBeVisible();
    for (const skip of [false, true]) {
      await setSwitch(page, 'deload.skipWarmUp', skip);
      const fingerprint = await programFingerprint(page);
      fingerprints.set(`${type}/skip=${skip}`, fingerprint);
      outputs.add(fingerprint);
    }
  }

  await setChoice(page.getByTestId('deload.type'), 'highIntensity');
  await expect(page.getByTestId('deload.skipWarmUp')).toHaveCount(0);
  options = commonOptions(await configuration(page));
  expect(options.deload).toEqual({ enabled: true, type: 'highIntensity' });
  const highIntensity = await programFingerprint(page);
  fingerprints.set('highIntensity', highIntensity);
  outputs.add(highIntensity);

  const duplicateGroups = [...fingerprints.entries()].reduce<Record<string, string[]>>(
    (groups, [label, fingerprint]) => {
      (groups[fingerprint] ??= []).push(label);
      return groups;
    },
    {},
  );
  expect(Object.values(duplicateGroups).filter((labels) => labels.length > 1)).toEqual([]);
  expect(external).toEqual([]);
});

test('GVT switches between one shared ratio and four effective movement ratios', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium-desktop',
    'The complete GVT option path is exercised once in deterministic Chromium.',
  );
  const external = await openCycle(page);
  await chooseCatalogVariant(
    page,
    'source_fsl_gvt',
    'source_calculator_gvt',
    'standard',
  );
  const movements = [
    'overhead_press',
    'deadlift',
    'bench_press',
    'squat',
  ] as const;

  for (const movement of movements) {
    await page.getByTestId(`max-load-${movement}`).fill('100');
  }
  await expect(page.getByTestId('gvt_use_same_ratio')).toBeChecked();
  await expect(page.getByTestId('gvt_percentage')).toBeVisible();
  for (const movement of movements) {
    await expect(
      page.getByTestId(`gvt_percentage_by_movement.${movement}`),
    ).toHaveCount(0);
  }

  await setChoice(page.getByTestId('gvt_percentage'), 40);
  await expect.poll(async () => {
    const request = await lastCycleRequest(page);
    return {
      shared: request?.percentageParameters,
      byMovement: request?.percentageParametersByMovement,
    };
  }).toEqual({
    shared: { gvt_percentage: 4000 },
    byMovement: {},
  });
  const sharedCycle = await generatedCycle(page);
  const sharedBlocks = firstGvtBlockByMovement(sharedCycle);
  expect([...sharedBlocks.keys()].sort()).toEqual([...movements].sort());
  for (const block of sharedBlocks.values()) {
    expect(block.sets).toHaveLength(10);
    expect(block.sets.every((set) => set.repetitions.count === 10)).toBe(true);
    expect(block.sets.every((set) => set.percentageBasisPoints === 4000)).toBe(true);
    expect(block.sets[0]?.plannedLoad?.centiUnits).toBeGreaterThan(0);
  }

  await page.getByTestId('gvt_use_same_ratio').uncheck();
  await expect(page.getByTestId('gvt_percentage')).toHaveCount(0);
  const ratios = {
    overhead_press: 3000,
    deadlift: 4000,
    bench_press: 5000,
    squat: 6000,
  } as const;
  for (const movement of movements) {
    const control = page.getByTestId(
      `gvt_percentage_by_movement.${movement}`,
    );
    await expect(control).toBeVisible();
    await setChoice(control, ratios[movement] / 100);
  }
  await expect.poll(async () =>
    (await lastCycleRequest(page))?.percentageParametersByMovement
  ).toEqual({
    overhead_press: { gvt_percentage: 3000 },
    deadlift: { gvt_percentage: 4000 },
    bench_press: { gvt_percentage: 5000 },
    squat: { gvt_percentage: 6000 },
  });

  const independentCycle = await generatedCycle(page);
  const independentBlocks = firstGvtBlockByMovement(independentCycle);
  expect([...independentBlocks.keys()].sort()).toEqual([...movements].sort());
  const loads: number[] = [];
  for (const movement of movements) {
    const block = independentBlocks.get(movement);
    expect(block, movement).toBeDefined();
    expect(
      block!.sets.every(
        (set) => set.percentageBasisPoints === ratios[movement],
      ),
      movement,
    ).toBe(true);
    const load = block!.sets[0]?.plannedLoad?.centiUnits;
    expect(load, movement).toBeGreaterThan(0);
    loads.push(load!);
  }
  expect(new Set(loads).size).toBe(4);
  expect(external).toEqual([]);
});

test('GVT movement ratios survive export, import, and a shared URL', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium-desktop',
    'Local transfer round-trips are exercised once in deterministic Chromium.',
  );
  const external = await openCycle(page);
  await chooseCatalogVariant(
    page,
    'source_fsl_gvt',
    'source_calculator_gvt',
    'standard',
  );
  await page.getByTestId('gvt_use_same_ratio').uncheck();
  const ratios = {
    overhead_press: 3500,
    deadlift: 4500,
    bench_press: 5500,
    squat: 6500,
  } as const;
  for (const [movement, ratio] of Object.entries(ratios)) {
    await setChoice(
      page.getByTestId(`gvt_percentage_by_movement.${movement}`),
      ratio / 100,
    );
  }
  await expect.poll(async () =>
    (await lastCycleRequest(page))?.percentageParametersByMovement
  ).toEqual({
    overhead_press: { gvt_percentage: 3500 },
    deadlift: { gvt_percentage: 4500 },
    bench_press: { gvt_percentage: 5500 },
    squat: { gvt_percentage: 6500 },
  });

  const exported = await configuration(page);
  expect(gvtConfigurationOptions(exported)).toEqual({
    gvt_use_same_ratio: false,
    gvt_percentage: ratios,
    gvt_alternate: false,
  });
  const sharedUrl = page.url();
  expect(sharedUrl).toMatch(/\?cycle=/);

  await page.getByTestId('gvt_use_same_ratio').check();
  await setChoice(page.getByTestId('gvt_percentage'), 30);
  await page.locator('input[type="file"]').setInputFiles({
    name: 'gvt-ratios.json',
    mimeType: 'application/json',
    buffer: Buffer.from(JSON.stringify(exported)),
  });
  await expect(page.getByTestId('gvt_use_same_ratio')).not.toBeChecked();
  for (const [movement, ratio] of Object.entries(ratios)) {
    await expect(
      page.getByTestId(`gvt_percentage_by_movement.${movement}`),
    ).toHaveValue(String(ratio / 100));
  }
  expect(gvtConfigurationOptions(await configuration(page))).toEqual({
    gvt_use_same_ratio: false,
    gvt_percentage: ratios,
    gvt_alternate: false,
  });

  await page.goto(sharedUrl);
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(page.getByTestId('gvt_use_same_ratio')).not.toBeChecked();
  for (const [movement, ratio] of Object.entries(ratios)) {
    await expect(
      page.getByTestId(`gvt_percentage_by_movement.${movement}`),
    ).toHaveValue(String(ratio / 100));
  }
  expect(gvtConfigurationOptions(await configuration(page))).toEqual({
    gvt_use_same_ratio: false,
    gvt_percentage: ratios,
    gvt_alternate: false,
  });
  expect(external).toEqual([]);
});

const noDeloadScenarios = [
  {
    name: 'FSL',
    generationId: 'source_fsl_gvt',
    templateId: 'source_calculator_first_set_last',
    variantId: 'standard',
    weeks: 3,
  },
  {
    name: 'GVT',
    generationId: 'source_fsl_gvt',
    templateId: 'source_calculator_gvt',
    variantId: 'standard',
    weeks: 3,
  },
  {
    name: 'Challenge Six Weeks',
    generationId: 'source_bbb_challenge',
    templateId: 'source_calculator_bbb_challenge',
    variantId: 'six_weeks',
    weeks: 6,
  },
  {
    name: 'Challenge Three Months',
    generationId: 'source_bbb_challenge',
    templateId: 'source_calculator_bbb_challenge',
    variantId: 'three_months',
    weeks: 9,
  },
  {
    name: 'Challenge Thirteen Weeks',
    generationId: 'source_bbb_challenge',
    templateId: 'source_calculator_bbb_challenge',
    variantId: 'thirteen_weeks',
    weeks: 12,
  },
  {
    name: 'Two Days Option One',
    generationId: 'source_two_day',
    templateId: 'source_calculator_two_days_per_week',
    variantId: 'option_one',
    weeks: 3,
  },
  {
    name: 'Two Days Option Two',
    generationId: 'source_two_day',
    templateId: 'source_calculator_two_days_per_week',
    variantId: 'option_two',
    weeks: 6,
  },
  {
    name: 'Two Days Option Three',
    generationId: 'source_two_day',
    templateId: 'source_calculator_two_days_per_week',
    variantId: 'option_three',
    weeks: 6,
  },
] as const;

test('deload off removes every deload week from all source families', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium-desktop',
    'The structural deload matrix runs once in deterministic Chromium.',
  );
  test.slow();
  test.setTimeout(180_000);
  const external = await openCycle(page);

  for (const scenario of noDeloadScenarios) {
    await chooseCatalogVariant(
      page,
      scenario.generationId,
      scenario.templateId,
      scenario.variantId,
    );
    const deload = page.getByTestId('deload.enabled');
    await expect(deload, scenario.name).toBeChecked();
    await deload.uncheck();
    await expect.poll(async () => {
      const request = await lastCycleRequest(page);
      const options = request?.options as
        | { readonly deload?: { readonly enabled?: unknown } }
        | undefined;
      return {
        templateId: request?.templateId,
        variantId: request?.variantId,
        includeDeload: request?.includeDeload,
        enabled: options?.deload?.enabled,
      };
    }).toEqual({
      templateId: scenario.templateId,
      variantId: scenario.variantId,
      includeDeload: false,
      enabled: false,
    });

    const cycle = await generatedCycle(page);
    expect(cycle.weeks, scenario.name).toHaveLength(scenario.weeks);
    expect(
      cycle.weeks
        .flatMap((week) => week.sessions)
        .flatMap((session) => session.blocks)
        .filter((block) => block.role === 'deload'),
      scenario.name,
    ).toEqual([]);
    await expect(page.locator('.program-week'), scenario.name).toHaveCount(
      scenario.weeks,
    );
  }
  expect(external).toEqual([]);
});

test('GVT scheduling applies 4/3/2-day cadence and reordered sessions to output', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium-desktop',
    'The complete scheduling matrix runs once in deterministic Chromium.',
  );
  test.slow();
  const external = await openCycle(page);
  await chooseCatalogVariant(
    page,
    'source_fsl_gvt',
    'source_calculator_gvt',
    'standard',
  );
  const schedules = [
    {
      id: 'schedule_four_day_fixed',
      weekCount: 4,
      firstWeekSessions: 4,
    },
    {
      id: 'schedule_three_day_rotating',
      weekCount: 5,
      firstWeekSessions: 3,
    },
    {
      id: 'schedule_two_day_rotating_four_lifts',
      weekCount: 7,
      firstWeekSessions: 2,
    },
  ] as const;

  for (const schedule of schedules) {
    await chooseSchedule(page, schedule.id);
    const request = await lastCycleRequest(page);
    expect(request?.sessionOrder, schedule.id).toEqual([
      'overhead_press',
      'deadlift',
      'bench_press',
      'squat',
    ]);
    const cycle = await generatedCycle(page);
    expect(cycle.weeks, schedule.id).toHaveLength(schedule.weekCount);
    expect(cycle.weeks[0]?.sessions, schedule.id).toHaveLength(
      schedule.firstWeekSessions,
    );
  }

  await chooseSchedule(page, 'schedule_four_day_fixed');
  const tokens = page.locator('.schedule-order__item .schedule-token');
  const before = await tokens.allTextContents();
  expect(before).toHaveLength(4);
  const firstTitleBefore = await page
    .locator('.program-week')
    .first()
    .locator('.session-card__title')
    .first()
    .innerText();
  await page
    .locator('.schedule-order__item')
    .first()
    .getByRole('button', { name: /right|droite/i })
    .click();
  await expect.poll(async () => (await lastCycleRequest(page))?.sessionOrder).toEqual([
    'deadlift',
    'overhead_press',
    'bench_press',
    'squat',
  ]);
  await expect.poll(() => tokens.allTextContents()).toEqual([
    before[1],
    before[0],
    before[2],
    before[3],
  ]);

  const reordered = await generatedCycle(page);
  expect(reordered.weeks[0]?.sessions[0]?.movementId).toBe('deadlift');
  const firstTitleAfter = await page
    .locator('.program-week')
    .first()
    .locator('.session-card__title')
    .first()
    .innerText();
  expect(firstTitleAfter).not.toBe(firstTitleBefore);
  expect(firstTitleAfter).toMatch(/deadlift|soulev/i);
  expect(external).toEqual([]);
});

function firstGvtBlockByMovement(
  cycle: GeneratedCycle,
): Map<string, GeneratedBlock> {
  const result = new Map<string, GeneratedBlock>();
  for (const week of cycle.weeks) {
    for (const session of week.sessions) {
      for (const block of session.blocks) {
        if (block.id === 'gvt_10x10' && !result.has(block.movementId)) {
          result.set(block.movementId, block);
        }
      }
    }
  }
  return result;
}

function gvtConfigurationOptions(
  artifact: Record<string, unknown>,
): Record<string, unknown> {
  const template = payload(artifact).template as
    | { readonly options?: Record<string, unknown> }
    | undefined;
  if (!template?.options) throw new Error('GVT_CONFIGURATION_OPTIONS_MISSING');
  return template.options;
}
