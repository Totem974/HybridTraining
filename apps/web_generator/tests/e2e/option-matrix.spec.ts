import { expect, test, type Download, type Locator, type Page } from '@playwright/test';
import { readFile } from 'node:fs/promises';

const localOrigin = 'http://127.0.0.1:4175';

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
  return external;
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
  const fingerprints = new Map<string, string>([['off', offFingerprint]]);
  const outputs = new Set<string>([offFingerprint]);
  let options = commonOptions(await configuration(page));
  expect(options.deload).toEqual({ enabled: false });

  await setSwitch(page, 'deload.enabled', true);
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
