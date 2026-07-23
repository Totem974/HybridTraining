import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/cycle/");
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
});

test("offers an accessible Cycle to Macrocycle switch", async ({ page }) => {
  const navigation = page.getByRole("navigation", { name: "Training generator" });
  await expect(navigation.getByRole("link", { name: "Cycle", exact: true })).toHaveAttribute(
    "aria-current",
    "page",
  );
  await expect(navigation.getByRole("link", { name: "Macrocycle" })).toHaveAttribute(
    "href",
    "/forever",
  );
});

test("persists collapsible sections locally", async ({ page }) => {
  const toggle = page.locator(
    '[data-collapsible-section="additional-options"] [data-collapse-toggle]',
  );
  await expect(toggle).toHaveAttribute("aria-expanded", "true");
  await toggle.click();
  await expect(toggle).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator("#additional-options-content")).toBeHidden();

  await page.reload();
  await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);
  await expect(page.locator(
    '[data-collapsible-section="additional-options"] [data-collapse-toggle]',
  )).toHaveAttribute(
    "aria-expanded",
    "false",
  );
});

for (const width of [390, 320]) {
  test(`does not overflow horizontally at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.reload();
    const dimensions = await page.evaluate(() => ({
      viewport: window.innerWidth,
      scroll: document.documentElement.scrollWidth,
    }));
    expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.viewport);
  });
}

test("keeps primary navigation and collapse controls at least 44px tall", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 900 });
  const targets = page.locator(
    ".page-switcher a, .locale-switch button, [data-collapse-toggle]",
  );
  for (let index = 0; index < await targets.count(); index += 1) {
    const box = await targets.nth(index).boundingBox();
    expect(Math.round(box?.height ?? 0)).toBeGreaterThanOrEqual(44);
  }
});

test("reorders training sessions with drag and drop", async ({ page }) => {
  const items = page.locator(".schedule-order__item");
  await expect(items).toHaveCount(4);
  const first = (await items.nth(0).innerText()).trim();
  const second = (await items.nth(1).innerText()).trim();

  await items.nth(0).dragTo(items.nth(3));

  await expect(items.nth(0)).toContainText(second.split(/\s/)[0] ?? second);
  await expect(items.nth(3)).toContainText(first.split(/\s/)[0] ?? first);
});
