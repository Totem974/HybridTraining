// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";

import {
  renderCycleForm,
  type CycleEditorSchema,
} from "../../../src/cycle/form";

const regions = [
  "weight",
  "template",
  "additional-options",
  "plating",
  "scheduling",
  "output",
] as const;

function shell(): HTMLElement {
  const root = document.createElement("main");
  for (const region of regions) {
    const mount = document.createElement("div");
    mount.dataset.cycleMount = region;
    root.append(mount);
  }
  return root;
}

const fields: CycleEditorSchema["fields"] = [
  {
    id: "warmup",
    path: "options.warmup",
    region: "additional-options",
    group: "warmup",
    groupLabel: "Warm-up",
    label: "Include warm-up",
    kind: "boolean",
    value: true,
  },
  {
    id: "joker",
    path: "options.joker",
    region: "additional-options",
    group: "joker",
    groupLabel: "Joker Sets",
    label: "Include joker sets",
    kind: "boolean",
    value: false,
  },
  {
    id: "deload",
    path: "options.deload",
    region: "additional-options",
    group: "deload",
    groupLabel: "Deload",
    label: "Include deload",
    kind: "boolean",
    value: true,
  },
  {
    id: "assistance",
    path: "options.assistance",
    region: "additional-options",
    group: "assistance",
    groupLabel: "Assistance",
    label: "Assistance plan",
    kind: "choice",
    value: "bodyweight",
    choices: [{ value: "bodyweight", label: "Bodyweight" }],
  },
  {
    id: "engine-only",
    path: "options.engineOnly",
    region: "additional-options",
    group: "hidden",
    groupLabel: "Engine",
    label: "Engine parameter",
    kind: "integer",
    value: 1,
  },
];

const schema: CycleEditorSchema = {
  apiVersion: "v1",
  engineVersion: "test",
  catalogVersion: 1,
  catalogHash: "hash",
  schemaVersion: 1,
  id: "additional-options-test",
  templateId: "standard",
  variantId: "default",
  movementIds: [],
  sessionIds: [],
  fields,
};

describe("Additional Options block", () => {
  it("keeps the schema order in three primary columns and a secondary row", () => {
    const root = shell();
    renderCycleForm({ schema, root, dispatch: vi.fn(), locale: "en" });

    const primary = root.querySelector(".additional-options__primary");
    expect(
      [...(primary?.children ?? [])].map((node) =>
        (node as HTMLElement).dataset.optionGroup
      ),
    ).toEqual(["warmup", "joker", "deload"]);
    expect(
      root.querySelector(".additional-options__secondary [data-option-group=assistance]"),
    ).not.toBeNull();
    expect(root.querySelector("[data-option-group=hidden]")).toBeNull();
  });

  it("preserves schema labels and field intents behind the visual Option row", () => {
    const root = shell();
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "en" });

    const checkbox = root.querySelector("[data-testid=warmup]") as HTMLInputElement;
    expect(root.querySelector(`label[for="${checkbox.id}"]`)?.textContent).toBe(
      "Include warm-up",
    );
    expect(checkbox.closest(".switch-row")?.textContent).toContain("Option");
    checkbox.checked = false;
    checkbox.dispatchEvent(new Event("change"));
    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "additional-options-test",
      fieldId: "warmup",
      path: "options.warmup",
      value: false,
    });
  });
});
