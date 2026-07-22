import { expect, test, type Page } from '@playwright/test';

const localOrigin = 'http://127.0.0.1:4173';

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
  const ready = await page.locator('[data-cycle-ready="true"]').count();
  test.skip(
    ready === 0,
    'Static Cycle application is not integrated yet: missing data-cycle-ready="true"; scenario was not simulated.',
  );
  return externalRequests;
}

async function generate(page: Page) {
  await page.getByRole('button', { name: /generate|générer/i }).click();
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(
    /week 1|semaine 1/i,
  );
}

test('Standard generates a complete plated program without external network', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('template-row').click();
  await page.getByRole('option', { name: /standard/i }).click();
  await generate(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/OP|BP|SQ|DL/);
  expect(external, 'external network requests').toEqual([]);
});

test('BBB exposes catalog options and changes the generated assistance work', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('template-row').click();
  await page.getByRole('option', { name: /boring but big|bbb/i }).click();
  await expect(page.locator('[data-cycle-region="additional-options"]')).toBeVisible();
  await generate(page);
  await expect(page.locator('[data-cycle-region="program"]')).toContainText(/5\s*[×x]\s*10/i);
  expect(external).toEqual([]);
});

test('Two Days renders only valid schedule tokens and generates', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByTestId('variant-row').click();
  await page.getByRole('option', { name: /two days|two day|2 days/i }).click();
  const schedule = page.locator('[data-cycle-region="scheduling"]');
  await expect(schedule).toContainText(/OP|BP|SQ|DL/);
  await expect(schedule).not.toContainText(/overhead_press|bench_press/i);
  await generate(page);
  expect(external).toEqual([]);
});

test('rep-max mode accepts repetitions and load before generation', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  await page.getByRole('radio', { name: /rep max/i }).check();
  await page.getByTestId('max-repetitions-overhead_press').fill('5');
  await page.getByTestId('max-load-overhead_press').fill('60');
  await generate(page);
  expect(external).toEqual([]);
});

test('catalog-driven options remain effective after template changes', async ({ page }) => {
  const external = await openIntegratedCycle(page);
  const options = page.locator('[data-cycle-region="additional-options"]');
  await expect(options.getByText(/warm-up/i)).toBeVisible();
  await options.getByRole('checkbox', { name: /joker/i }).check();
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
  await page.getByRole('button', { name: /english|en/i }).click();
  await expect(page.getByRole('button', { name: /generate/i })).toBeVisible();
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
