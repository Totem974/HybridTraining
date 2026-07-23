import { expect, test, type Locator } from "@playwright/test";

for (const width of [390, 320]) {
  test(`reorders sessions with touch Pointer Events at ${width}px`, async ({
    page,
  }, testInfo) => {
    test.skip(
      testInfo.project.name !== "chromium-390",
      "The touch interaction is exercised once in the mobile Chromium context.",
    );
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/cycle/");
    await expect(page.locator('[data-cycle-ready="true"]')).toHaveCount(1);

    const items = page.locator(".schedule-order__item");
    await expect(items.first()).toHaveAttribute("draggable", "true");
    const count = await items.count();
    expect(count).toBeGreaterThan(1);
    const before = await tokenLabels(items);
    const source = items.first();
    const destination = items.last();
    const sourceBox = await source.boundingBox();
    const destinationBox = await destination.boundingBox();
    expect(sourceBox).not.toBeNull();
    expect(destinationBox).not.toBeNull();

    await source.dispatchEvent("pointerdown", {
      pointerId: 41,
      pointerType: "touch",
      isPrimary: true,
      button: 0,
      buttons: 1,
      clientX: sourceBox!.x + sourceBox!.width / 2,
      clientY: sourceBox!.y + sourceBox!.height / 2,
    });
    await expect(source).toHaveClass(/is-dragging/);

    await destination.dispatchEvent("pointermove", {
      pointerId: 41,
      pointerType: "touch",
      isPrimary: true,
      button: -1,
      buttons: 1,
      clientX: destinationBox!.x + destinationBox!.width / 2,
      clientY: destinationBox!.y + destinationBox!.height / 2,
    });
    await expect(destination).toHaveClass(/is-drag-over/);

    await destination.dispatchEvent("pointerup", {
      pointerId: 41,
      pointerType: "touch",
      isPrimary: true,
      button: 0,
      buttons: 0,
      clientX: destinationBox!.x + destinationBox!.width / 2,
      clientY: destinationBox!.y + destinationBox!.height / 2,
    });

    await expect.poll(() => tokenLabels(items)).toEqual([
      ...before.slice(1),
      before[0],
    ]);
  });
}

async function tokenLabels(
  items: Locator,
): Promise<readonly string[]> {
  return items.evaluateAll((entries: Element[]) =>
    entries.map((entry) =>
      entry.querySelector(".schedule-token")?.textContent?.trim() ?? ""
    )
  );
}
