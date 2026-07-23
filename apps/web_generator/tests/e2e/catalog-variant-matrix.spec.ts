import { expect, test, type Locator, type Page } from '@playwright/test';

const localOrigin = 'http://127.0.0.1:4173';

type SelectOption = {
  label: string;
  value: string;
};

async function options(select: Locator): Promise<SelectOption[]> {
  return select.locator('option').evaluateAll((elements) =>
    elements
      .map((element) => {
        const option = element as HTMLOptionElement;
        return { label: option.label.trim(), value: option.value };
      })
      .filter(({ value }) => value.length > 0),
  );
}

async function expectRenderedProgram(page: Page, context: string): Promise<void> {
  const status = page.locator('#engine-status');
  const program = page.locator('[data-cycle-region="program"]');

  await expect
    .poll(() => status.innerText(), { message: context })
    .toMatch(/generated|généré|exception|error|erreur/i);
  expect.soft(await status.innerText(), context).toMatch(/generated|généré/i);
  expect.soft(await program.locator('.program-week').count(), context).toBeGreaterThan(0);
  expect.soft(await program.innerText(), context).toMatch(/week 1|semaine 1/i);
  expect.soft(await program.innerText(), context).not.toMatch(
    /(?:ENGINE|CATALOG|VALIDATION)_[A-Z0-9_]+|(?:template|variant|schedule)Id|"[A-Za-z][^"]*"\s*:|\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b|^\s*[\[{]/m,
  );
}

test('every public catalog variant generates a presentable program locally', async ({ page }) => {
  test.slow();
  test.setTimeout(120_000);

  const externalRequests: string[] = [];
  const pageErrors: string[] = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));
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

  const generationSelect = page.getByTestId('generation-row').getByRole('combobox');
  const templateSelect = page.getByTestId('template-row').getByRole('combobox');
  const variantSelect = page.getByTestId('variant-row').getByRole('combobox');
  const visited = new Set<string>();

  for (const generation of await options(generationSelect)) {
    await generationSelect.selectOption(generation.value);

    for (const template of await options(templateSelect)) {
      await templateSelect.selectOption(template.value);

      for (const variant of await options(variantSelect)) {
        const context = `${generation.label} / ${template.label} / ${variant.label}`;
        await variantSelect.selectOption(variant.value);
        await expect(variantSelect, context).toHaveValue(variant.value);
        await expectRenderedProgram(page, context);

        const visibleText = await page.locator('[data-cycle-region="program"]').innerText();
        expect(visibleText.trim().length, context).toBeGreaterThan(40);
        visited.add(`${generation.value}/${template.value}/${variant.value}`);
      }
    }
  }

  expect(visited.size, 'the public catalog must expose variants').toBeGreaterThan(0);
  expect(pageErrors, 'uncaught browser errors').toEqual([]);
  expect(externalRequests, 'external network requests').toEqual([]);
});
