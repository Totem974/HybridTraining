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

async function generate(page: Page) {
  await page.getByTestId('generate').click();
  const engineStatus = await page.locator('#engine-status').textContent();
  expect(engineStatus, 'engine status after generation').not.toMatch(/error|required|invalid|exception/i);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(
    /week 1|semaine 1/i,
  );
}

test('Standard generates a complete plated program without external network', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await generate(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/press|deadlift|squat/i);
  expect(external, 'external network requests').toEqual([]);
});

test('BBB exposes catalog options and changes the generated assistance work', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('template-row').getByRole('combobox').selectOption({ label: 'Boring But Big' });
  await expect(page.locator('[data-cycle-region="additional-options"]')).toBeVisible();
  await generate(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/10\s*[×x]/i);
  const scheduling = page.locator('[data-cycle-region="scheduling"]');
  await expect(scheduling.locator('.token')).toHaveCount(4);
  expect(external).toEqual([]);
});

test('Two Days renders only valid schedule tokens and generates', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('variant-row').getByRole('combobox').selectOption({ label: 'Two-day rotation' });
  const schedule = page.locator('[data-cycle-region="scheduling"]');
  await expect(schedule).toContainText(/SQ\+BP/);
  await expect(schedule).toContainText(/DL\+OP/);
  await expect(schedule).not.toContainText(/overhead_press|bench_press/i);
  await generate(page);
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
    await page.getByTestId(`max-load-${movement}`).fill(load);
  }
  for (const [movement, repetitions] of inputs) {
    await expect(page.getByTestId(`max-repetitions-${movement}`)).toHaveValue(repetitions);
  }
  await generate(page);
  expect(external).toEqual([]);
});

test('catalog-driven options remain effective after template changes', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const options = page.locator('[data-cycle-region="additional-options"]');
  await expect(options.getByRole('group', { name: /warm-up|échauffement/i })).toBeVisible();
  await options.getByRole('checkbox', { name: /warm-up|échauffement/i }).uncheck();
  await options.getByRole('checkbox', { name: /deload/i }).uncheck();
  await generate(page);
  expect(external).toEqual([]);
});

test('plating visibility and local persistence survive reload', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByRole('checkbox', { name: /show plating|afficher les plaques/i }).check();
  await generate(page);
  await expect(page.locator('[data-plate]')).not.toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('checkbox', { name: /show plating|afficher les plaques/i })).toBeChecked();
  expect(external).toEqual([]);
});

test('FR and EN labels switch locally', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByRole('button', { name: /français|fr/i }).click();
  await expect(page.getByRole('button', { name: /générer/i })).toBeVisible();
  await page.getByRole('button', { name: /^english$/i }).click();
  await expect(page.getByRole('button', { name: /generate/i })).toBeVisible();
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

for (const width of [1440, 390, 320]) {
  test(`responsive Cycle flow remains usable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: width > 500 ? 1000 : 844 });
    const external = await openIntegratedCycle(page);
    await expect(page.locator('#cycle-form')).toBeVisible();
    await expect(page.locator('body')).not.toHaveCSS('overflow-x', 'scroll');
    await generate(page);
    expect(external).toEqual([]);
  });
}

for (const width of [1440, 390, 320]) {
  test(`records Cycle visual evidence at ${width}px`, async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium-desktop', 'Visual evidence is recorded once with deterministic Chromium.');
    await page.setViewportSize({ width, height: width > 500 ? 1100 : 844 });
    const external = await openIntegratedCycle(page);
    await generate(page);
    await mkdir(visualEvidenceDirectory, { recursive: true });
    await page.screenshot({
      path: resolve(visualEvidenceDirectory, `cycle-${width}.png`),
      fullPage: true,
      animations: 'disabled',
    });
    expect(external).toEqual([]);
  });
}
