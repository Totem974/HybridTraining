import { expect, test, type Page } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const localOrigin = 'http://127.0.0.1:4173';
const visualEvidenceDirectory = resolve('tests', 'visual-evidence');

async function openIntegratedCycle(page: Page): Promise<string[]> {
  const externalRequests: string[] = [];
  await page.route('**/*', async (route) => {
    const url = new URL(route.request().url());
    if (url.origin !== localOrigin) {
      externalRequests.push(url.href);
      await route.abort('blockedbyclient');
      return;
    }
    await route.continue();
  });
  await page.goto('/cycle/');
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  return externalRequests;
}

async function awaitGeneratedProgram(page: Page) {
  await expect(page.locator('#engine-status')).toContainText(/generated|généré/i);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(
    /week 1|semaine 1/i,
  );
}

test('Standard generates a complete plated program without external network', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await awaitGeneratedProgram(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/press|deadlift|squat/i);
  expect(external, 'external network requests').toEqual([]);
});

test('BBB exposes catalog options and changes the generated assistance work', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('template-row').getByRole('combobox').selectOption({ label: 'Boring But Big' });
  await expect(page.locator('[data-cycle-region="additional-options"]')).toBeVisible();
  await awaitGeneratedProgram(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/10\s*[×x]/i);
  const scheduling = page.locator('[data-cycle-region="scheduling"]');
  await expect(scheduling.locator('.schedule-token')).toHaveCount(4);
  expect(external).toEqual([]);
});

test('Beyond BBB exposes and generates both sourced wave variants', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.evaluate(() => {
    const engine = window.hybridTrainingEngine;
    if (!engine) throw new Error('ENGINE_BRIDGE_UNAVAILABLE');
    const generateCycle = engine.generateCycle.bind(engine);
    engine.generateCycle = (requestJson: string) => {
      document.documentElement.dataset.lastCycleRequest = requestJson;
      return generateCycle(requestJson);
    };
  });
  const generation = page
    .getByTestId('generation-row')
    .getByRole('combobox');
  await generation.selectOption(JSON.stringify('beyond'));
  await expect(generation).toHaveValue(JSON.stringify('beyond'));
  const template = page
    .getByTestId('template-row')
    .getByRole('combobox');
  await expect(template.locator('option[value*="beyond_boring_but_big"]')).toHaveCount(1);
  await template.selectOption(JSON.stringify('beyond_boring_but_big'));
  await expect(template).toHaveValue(JSON.stringify('beyond_boring_but_big'));
  const variant = page.getByTestId('variant-row').getByRole('combobox');

  await expect(variant.locator('option[value*="variation_i_5x10_wave"]')).toHaveCount(1);
  await variant.selectOption(JSON.stringify('variation_i_5x10_wave'));
  await expect(variant).toHaveValue(JSON.stringify('variation_i_5x10_wave'));
  await expect.poll(async () => {
    const raw = await page.locator('html').getAttribute('data-last-cycle-request');
    return raw ? JSON.parse(raw).variantId : undefined;
  }).toBe('variation_i_5x10_wave');
  const firstRequest = JSON.parse(
    (await page.locator('html').getAttribute('data-last-cycle-request'))!,
  );
  expect(firstRequest.includeDeload).toBe(true);
  expect(firstRequest.options).toEqual({});
  await expect(page.locator('.program-week')).toHaveCount(7);
  await expect(page.locator('.program-week').nth(1)).toContainText(/10\s*[×x]/i);

  await variant.selectOption(JSON.stringify('variation_ii_descending_volume'));
  await expect(variant).toHaveValue(JSON.stringify('variation_ii_descending_volume'));
  await expect(page.locator('.program-week')).toHaveCount(7);
  await expect(page.locator('.program-week').nth(1)).toContainText(/8\s*[×x]/i);
  await expect(page.locator('.program-week').nth(2)).toContainText(/5\s*[×x]/i);
  expect(external).toEqual([]);
});

test('Two Days renders only valid schedule tokens and generates', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('template-row').getByRole('combobox').selectOption(JSON.stringify('classic_531'));
  await page.getByTestId('variant-row').getByRole('combobox').selectOption(JSON.stringify('two_day_rotation'));
  await page.getByRole('radio', { name: /paired lifts|deux mouvements/i }).check();
  const schedule = page.locator('[data-cycle-region="scheduling"]');
  await expect(schedule).toContainText(/SQ\+BP/);
  await expect(schedule).toContainText(/DL\+OP/);
  await expect(schedule).not.toContainText(/overhead_press|bench_press/i);
  await awaitGeneratedProgram(page);
  expect(external).toEqual([]);
});

test('rep-max mode accepts repetitions and load before generation', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByRole('radio', { name: /rep max/i }).check();
  const inputs = [
    ['overhead_press', '3', '60'],
    ['deadlift', '5', '140'],
    ['bench_press', '7', '90'],
    ['squat', '9', '120'],
  ] as const;
  for (const [movement, repetitions, load] of inputs) {
    await page.getByTestId(`max-repetitions-${movement}`).fill(repetitions);
    await page.getByTestId(`max-repetitions-${movement}`).blur();
    await page.getByTestId(`max-load-${movement}`).fill(load);
    await page.getByTestId(`max-load-${movement}`).blur();
  }
  for (const [movement, repetitions] of inputs) {
    await expect(page.getByTestId(`max-repetitions-${movement}`)).toHaveValue(repetitions);
  }
  await awaitGeneratedProgram(page);
  expect(external).toEqual([]);
});

test('catalog-driven options remain effective after template changes', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const options = page.locator('[data-cycle-region="additional-options"]');
  await expect(options.getByRole('group', { name: /warm-up|échauffement/i })).toBeVisible();
  await page.getByTestId('warmUp.enabled').uncheck();
  await page.getByTestId('deload.enabled').uncheck();
  await awaitGeneratedProgram(page);
  expect(external).toEqual([]);
});

test('Generation filters templates between Classic and Beyond', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const generation = page.getByTestId('generation-row').getByRole('combobox');
  const template = page.getByTestId('template-row').getByRole('combobox');

  await expect(generation).toHaveValue(JSON.stringify('classic'));
  await generation.selectOption(JSON.stringify('beyond'));
  await expect(generation).toHaveValue(JSON.stringify('beyond'));
  await expect(template).toHaveValue(/"beyond_/);
  expect(await template.locator('option').evaluateAll(
    (options) => options.every((option) => JSON.parse(
      (option as HTMLOptionElement).value,
    ).startsWith('beyond_')),
  )).toBe(true);

  await generation.selectOption(JSON.stringify('classic'));
  await expect(generation).toHaveValue(JSON.stringify('classic'));
  await expect(template).not.toHaveValue(/"beyond_/);
  expect(external).toEqual([]);
});

test('Additional Options keeps Warm-up, Joker Sets and Deload for every template', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const generation = page.getByTestId('generation-row').getByRole('combobox');
  const template = page.getByTestId('template-row').getByRole('combobox');

  for (const generationId of ['classic', 'beyond']) {
    await generation.selectOption(JSON.stringify(generationId));
    const templateIds = await template.locator('option').evaluateAll(
      (options) => options.map((option) => (option as HTMLOptionElement).value),
    );
    for (const templateId of templateIds) {
      await template.selectOption(templateId);
      await expect(
        page.locator(
          '[data-cycle-region="additional-options"] '
          + '.additional-options__primary > [data-option-group]',
        ),
      ).toHaveCount(3);
    }
  }

  expect(external).toEqual([]);
});

test('Plating spans the editor before the Scheduling and Output row', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const layout = await page.evaluate(() => {
    const form = document.querySelector('#cycle-form')!.getBoundingClientRect();
    const plating = document.querySelector('#plating')!.getBoundingClientRect();
    const scheduling = document.querySelector('#scheduling')!.getBoundingClientRect();
    const output = document.querySelector('#output')!.getBoundingClientRect();
    const program = document.querySelector('#program')!.getBoundingClientRect();
    return {
      formWidth: form.width,
      platingWidth: plating.width,
      platingBottom: plating.bottom,
      schedulingTop: scheduling.top,
      schedulingLeft: scheduling.left,
      outputTop: output.top,
      outputLeft: output.left,
      programTop: program.top,
      rowBottom: Math.max(scheduling.bottom, output.bottom),
    };
  });

  expect(Math.abs(layout.formWidth - layout.platingWidth)).toBeLessThan(2);
  expect(layout.schedulingTop).toBeGreaterThanOrEqual(layout.platingBottom);
  if ((page.viewportSize()?.width ?? 1440) > 770) {
    expect(Math.abs(layout.schedulingTop - layout.outputTop)).toBeLessThan(2);
    expect(layout.outputLeft).toBeGreaterThan(layout.schedulingLeft);
  } else {
    expect(layout.outputTop).toBeGreaterThan(layout.schedulingTop);
    expect(Math.abs(layout.outputLeft - layout.schedulingLeft)).toBeLessThan(2);
  }
  expect(layout.programTop).toBeGreaterThanOrEqual(layout.rowBottom);
  expect(external).toEqual([]);
});

test('plating visibility and local persistence survive reload', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByRole('checkbox', { name: /show plating|afficher les plaques/i }).check();
  await awaitGeneratedProgram(page);
  await expect(page.locator('[data-plate]')).not.toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('checkbox', { name: /show plating|afficher les plaques/i })).toBeChecked();
  expect(external).toEqual([]);
});

test('FR and EN labels switch locally', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await awaitGeneratedProgram(page);
  await page.getByRole('button', { name: /^fr$/i }).click();
  await expect(page.getByRole('checkbox', { name: /afficher les plaques/i })).toBeVisible();
  await expect(page.locator('.program-week__title').first()).toContainText('SEMAINE');
  await page.getByRole('button', { name: /^en$/i }).click();
  await expect(page.getByRole('checkbox', { name: /show plating/i })).toBeVisible();
  await expect(page.locator('.program-week__title').first()).toContainText('WEEK');
  expect(external).toEqual([]);
});

test('configuration import and configuration/program exports stay local', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const configurationDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: /export.*configuration|exporter.*configuration/i }).click();
  const configuration = await configurationDownload;
  const configurationPath = await configuration.path();
  expect(configurationPath).toBeTruthy();
  await page.locator('input[type="file"]').setInputFiles(configurationPath!);
  await expect(page.locator('#engine-status')).toContainText(/generated|généré/i);

  const programDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: /export.*program|exporter.*programme/i }).click();
  const exportedProgram = await programDownload;
  expect(await exportedProgram.path()).toBeTruthy();
  expect(external).toEqual([]);
});

test('share URL restores the canonical configuration locally', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('joker.enabled').check();
  await expect(page).toHaveURL(/\?cycle=/);
  const sharedUrl = page.url();
  await page.getByTestId('joker.enabled').uncheck();
  await page.goto(sharedUrl);
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(page.getByTestId('joker.enabled')).toBeChecked();
  await awaitGeneratedProgram(page);
  expect(external).toEqual([]);
});

test('shared plating choice takes precedence over the local preference', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const showPlating = page.getByRole('checkbox', {
    name: /show plating|afficher les plaques/i,
  });
  if (await showPlating.isChecked()) await showPlating.uncheck();
  await expect(showPlating).not.toBeChecked();
  const sharedWithoutPlating = page.url();

  await showPlating.check();
  await expect(showPlating).toBeChecked();
  await page.goto(sharedWithoutPlating);

  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(showPlating).not.toBeChecked();
  expect(external).toEqual([]);
});

test('invalid shared configuration is ignored without blocking Cycle', async ({ page }) => {
  const malformed = Buffer.from(JSON.stringify({
    format: 'hybrid-training-cycle',
    configurationVersion: 1,
    catalogVersion: 7,
    catalogHash: 'sha256:test',
  })).toString('base64url');

  await page.goto(`/cycle/?cycle=${malformed}`);

  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(page).not.toHaveURL(new RegExp(`cycle=${malformed}`));
  await awaitGeneratedProgram(page);
});

for (const width of [1440, 390, 320]) {
  test(`responsive Cycle flow remains usable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: width > 500 ? 1000 : 844 });
    const external = await openIntegratedCycle(page);
    await expect(page.locator('#cycle-form')).toBeVisible();
    await expect(page.locator('body')).not.toHaveCSS('overflow-x', 'scroll');
    await awaitGeneratedProgram(page);
    expect(external).toEqual([]);
  });
}

for (const width of [1440, 390, 320]) {
  test(`records Cycle visual evidence at ${width}px`, async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium-desktop', 'Visual evidence is recorded once with deterministic Chromium.');
    await page.setViewportSize({ width, height: width > 500 ? 1100 : 844 });
    const external = await openIntegratedCycle(page);
    await awaitGeneratedProgram(page);
    await mkdir(visualEvidenceDirectory, { recursive: true });
    await page.screenshot({
      path: resolve(visualEvidenceDirectory, `cycle-${width}.png`),
      fullPage: true,
      animations: 'disabled',
    });
    expect(external).toEqual([]);
  });
}
