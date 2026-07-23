import { expect, test, type Locator, type Page } from '@playwright/test';

const localOrigin = 'http://127.0.0.1:4175';

const expectedPublicCatalog = {
  beyond: {
    beyond_boring_but_big: [
      'same_lift_5x10_50_two_cycles',
      'variation_i_5x10_wave',
      'variation_ii_descending_volume',
    ],
    beyond_first_set_last: ['amrap_four_day_two_cycles'],
    beyond_fives_progression: ['main_lifts_four_day_two_cycles'],
    beyond_pyramid: ['four_day_two_cycles'],
  },
  classic: {
    classic_531: ['four_day', 'three_day_rotation', 'two_day_rotation'],
    classic_bodyweight: ['four_day'],
    classic_boring_but_big: ['same_lift_5x10'],
    classic_for_beginners: ['original_progression'],
    classic_full_body: ['full_boring', 'original', 'updated'],
    classic_jack_shit: ['main_lift_only'],
    classic_periodization_bible: ['four_day'],
    classic_simplest_strength: ['original', 'powerlifting'],
    classic_triumvirate: ['four_day'],
    powerlifting_classic_531: ['four_day_531_deload'],
  },
  source_bbb_challenge: {
    source_calculator_bbb_challenge: [
      'six_weeks',
      'thirteen_weeks',
      'three_months',
    ],
  },
  source_fsl_gvt: {
    source_calculator_first_set_last: ['standard'],
    source_calculator_gvt: ['standard'],
  },
  source_parity: {
    source_calculator_boring_but_big: [
      'beyond_variation_one',
      'beyond_variation_two',
      'five_by_five_80',
      'five_by_one_100',
      'five_by_three_90',
      'less_boring_5x10',
      'original_5x10',
      'two_days_per_week',
    ],
  },
  source_two_day: {
    source_calculator_two_days_per_week: [
      'option_one',
      'option_three',
      'option_two',
    ],
  },
} as const satisfies Readonly<
  Record<string, Readonly<Record<string, readonly string[]>>>
>;

type SelectOption = {
  readonly id: string;
  readonly label: string;
};

async function options(select: Locator): Promise<SelectOption[]> {
  const raw = await select.locator('option').evaluateAll((elements) =>
    elements
      .map((element) => {
        const option = element as HTMLOptionElement;
        return { label: option.label.trim(), value: option.value };
      })
      .filter(({ value }) => value.length > 0),
  );
  return raw.map(({ label, value }) => {
    const id = JSON.parse(value) as unknown;
    if (typeof id !== 'string') throw new Error(`NON_STRING_CATALOG_ID:${value}`);
    return { id, label };
  });
}

function sorted(values: readonly string[]): string[] {
  return [...values].sort((left, right) => left.localeCompare(right));
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

async function expectSelectedRequest(
  page: Page,
  generationId: string,
  templateId: string,
  variantId: string,
): Promise<void> {
  await expect.poll(async () => {
    const raw = await page.locator('html').getAttribute('data-last-cycle-request');
    if (!raw) return undefined;
    const request = JSON.parse(raw) as {
      readonly templateId?: unknown;
      readonly variantId?: unknown;
    };
    return {
      generationId,
      templateId: request.templateId,
      variantId: request.variantId,
    };
  }).toEqual({ generationId, templateId, variantId });
}

async function expectRenderedProgram(page: Page, context: string): Promise<void> {
  const status = page.locator('#engine-status');
  const program = page.locator('[data-cycle-region="program"]');

  await expect
    .poll(() => status.innerText(), { message: context })
    .toMatch(
      /generated|g(?:\u00e9|\u00c3\u00a9)n(?:\u00e9|\u00c3\u00a9)r(?:\u00e9|\u00c3\u00a9)|exception|error|erreur/i,
    );
  expect.soft(await status.innerText(), context).toMatch(
    /generated|g(?:\u00e9|\u00c3\u00a9)n(?:\u00e9|\u00c3\u00a9)r(?:\u00e9|\u00c3\u00a9)/i,
  );
  expect.soft(await program.locator('.program-week').count(), context).toBeGreaterThan(0);
  expect.soft(await program.innerText(), context).toMatch(/week 1|semaine 1/i);
  expect.soft(await program.innerText(), context).not.toMatch(
    /(?:ENGINE|CATALOG|VALIDATION)_[A-Z0-9_]+|(?:template|variant|schedule)Id|"[A-Za-z][^"]*"\s*:|\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b|^\s*[\[{]/m,
  );
}

test('all 19 public templates and 37 variants generate from the catalog', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium-desktop',
    'The exhaustive catalog matrix runs once; browser smoke coverage is separate.',
  );
  test.slow();
  test.setTimeout(180_000);

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
  await installRequestRecorder(page);
  await page
    .locator('[data-cycle-region="output"] input[name="programTitle"]')
    .fill('Catalog matrix');
  await expect.poll(() =>
    page.locator('html').getAttribute('data-last-cycle-request')
  ).not.toBeNull();

  const generationSelect = page.getByTestId('generation-row').getByRole('combobox');
  const templateSelect = page.getByTestId('template-row').getByRole('combobox');
  const variantSelect = page.getByTestId('variant-row').getByRole('combobox');
  const generationOptions = await options(generationSelect);
  expect(sorted(generationOptions.map(({ id }) => id))).toEqual(
    sorted(Object.keys(expectedPublicCatalog)),
  );

  const visited = new Set<string>();
  const visitedTemplates = new Set<string>();
  for (const generation of generationOptions) {
    const expectedTemplates = expectedPublicCatalog[
      generation.id as keyof typeof expectedPublicCatalog
    ];
    expect(expectedTemplates, `unexpected generation ${generation.id}`).toBeDefined();
    await generationSelect.selectOption(JSON.stringify(generation.id));
    await expect(generationSelect).toHaveValue(JSON.stringify(generation.id));
    await expect.poll(async () =>
      sorted((await options(templateSelect)).map(({ id }) => id))
    ).toEqual(sorted(Object.keys(expectedTemplates)));

    for (const template of await options(templateSelect)) {
      const expectedVariants = expectedTemplates[
        template.id as keyof typeof expectedTemplates
      ] as readonly string[] | undefined;
      expect(
        expectedVariants,
        `unexpected template ${generation.id}/${template.id}`,
      ).toBeDefined();
      await templateSelect.selectOption(JSON.stringify(template.id));
      await expect(templateSelect).toHaveValue(JSON.stringify(template.id));
      await expect.poll(async () =>
        sorted((await options(variantSelect)).map(({ id }) => id))
      ).toEqual(sorted(expectedVariants!));
      visitedTemplates.add(`${generation.id}/${template.id}`);

      for (const variant of await options(variantSelect)) {
        const context = `${generation.label} / ${template.label} / ${variant.label}`;
        await variantSelect.selectOption(JSON.stringify(variant.id));
        await expect(variantSelect, context).toHaveValue(JSON.stringify(variant.id));
        await expectSelectedRequest(
          page,
          generation.id,
          template.id,
          variant.id,
        );
        await expectRenderedProgram(page, context);

        const visibleText = await page.locator('[data-cycle-region="program"]').innerText();
        expect(visibleText.trim().length, context).toBeGreaterThan(40);
        visited.add(`${generation.id}/${template.id}/${variant.id}`);
      }
    }
  }

  expect(visitedTemplates.size, 'public template coverage').toBe(19);
  expect(visited.size, 'public variant coverage').toBe(37);
  expect(pageErrors, 'uncaught browser errors').toEqual([]);
  expect(externalRequests, 'external network requests').toEqual([]);
});
