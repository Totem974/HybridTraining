// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";

import { renderPlatingBlock } from "../../../../src/cycle/form/blocks/plating";
import type {
  CycleBlockRenderContext,
  CycleEditorField,
} from "../../../../src/cycle/form/types";

const fields: readonly CycleEditorField[] = [
  {
    id: "equipment-profile",
    path: "equipment.profile",
    region: "plating",
    label: { en: "Profile", fr: "Profil" },
    kind: "choice",
    value: "standard",
    choices: [
      { value: "standard", label: "Standard" },
      { value: "home", label: { en: "Home", fr: "Maison" } },
    ],
  },
  {
    id: "plate-20",
    path: "plates.20",
    region: "plating",
    label: "20 kg",
    kind: "plate-counter",
    value: 1,
    minimum: 0,
    maximum: 2,
  },
  {
    id: "bar-weight",
    path: "barWeight",
    region: "plating",
    label: { en: "Bar weight", fr: "Poids de la barre" },
    kind: "weight",
    value: 20,
    minimum: 0,
    step: 0.5,
  },
  {
    id: "maximum-plate-load",
    path: "maximumPlateLoad",
    region: "plating",
    label: { en: "Maximum total", fr: "Total maximal" },
    kind: "weight",
    value: 180,
    readOnly: true,
  },
];

function render(dispatch = vi.fn()): { root: HTMLElement; dispatch: ReturnType<typeof vi.fn> } {
  const context: CycleBlockRenderContext = {
    fields,
    locale: "fr",
    schemaId: "editor-v1",
    dispatch,
    values: Object.fromEntries(fields.map((field) => [field.path, field.value])),
    renderDefault: () => document.createDocumentFragment(),
  };
  const root = document.createElement("div");
  root.append(renderPlatingBlock(context));
  return { root, dispatch };
}

describe("renderPlatingBlock", () => {
  it("renders schema-provided profile, compact counters and engine total", () => {
    const { root } = render();
    expect(root.querySelector("select")?.labels?.[0]?.textContent).toBe("Profil");
    expect(root.querySelector("select")?.selectedOptions[0]?.textContent).toBe("Standard");
    expect(root.querySelector(".plating-grid")?.children).toHaveLength(1);
    expect(root.querySelector(".plating-summary__item--bar label")?.textContent).toBe(
      "Poids de la barre",
    );
    expect(root.querySelector(".plating-summary__item--maximum output")?.textContent).toBe(
      "180",
    );
    expect(root.textContent).not.toMatch(/arrondi|plaques par côté/i);
  });

  it("emits only schema path/value intents for counter changes", () => {
    const { root, dispatch } = render();
    (root.querySelector('[data-testid="plate-20-increment"]') as HTMLButtonElement).click();
    (root.querySelector('[data-testid="plate-20-increment"]') as HTMLButtonElement).click();
    expect(dispatch).toHaveBeenNthCalledWith(1, {
      type: "cycle.field.changed",
      schemaId: "editor-v1",
      fieldId: "plate-20",
      path: "plates.20",
      value: 2,
    });
    expect(dispatch).toHaveBeenNthCalledWith(2, expect.objectContaining({ value: 2 }));
  });
});
