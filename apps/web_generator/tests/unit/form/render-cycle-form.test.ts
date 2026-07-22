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
];

function shell(): HTMLElement {
  const root = document.createElement("main");
  for (const region of regions) {
    const mount = document.createElement("div");
    mount.dataset.cycleMount = region;
    root.append(mount);
  }
  return root;
}

const schema: CycleEditorSchema = {
  apiVersion: "v1",
  engineVersion: "test",
  catalogVersion: 1,
  catalogHash: "hash",
  schemaVersion: 1,
  id: "editor",
  templateId: "alpha",
  variantId: "default",
  movementIds: [],
  sessionIds: [],
  fields: [
    {
      id: "template",
      path: "templateId",
      region: "template",
      label: { en: "Template", fr: "Modèle" },
      kind: "choice",
      value: "alpha",
      choices: [
        { value: "alpha", label: "Alpha" },
        { value: "beta", label: "Beta" },
      ],
    },
    {
      id: "show-plating",
      path: "output.showPlating",
      region: "output",
      label: "Show plating",
      kind: "boolean",
      value: true,
    },
    {
      id: "generate",
      path: "actions.generate",
      region: "output",
      label: "Generate",
      kind: "action",
      value: null,
      action: "generateCycle",
    },
  ],
};

describe("renderCycleForm", () => {
  it("renders schema controls into stable shell mounts", () => {
    const root = shell();
    renderCycleForm({ schema, root, dispatch: vi.fn(), locale: "fr" });
    expect(root.querySelector("[data-cycle-mount=template] label")?.textContent).toBe(
      "Modèle",
    );
    expect(root.querySelectorAll("select option")).toHaveLength(2);
    expect((root.querySelector("input[type=checkbox]") as HTMLInputElement).checked).toBe(true);
  });

  it("emits generic path/value intents and no training calculation", () => {
    const root = shell();
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch });
    const select = root.querySelector("select") as HTMLSelectElement;
    select.value = JSON.stringify("beta");
    select.dispatchEvent(new Event("change"));
    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "editor",
      fieldId: "template",
      path: "templateId",
      value: "beta",
    });
  });

  it("returns a cleanup that empties only owned mounts", () => {
    const root = shell();
    const cleanup = renderCycleForm({ schema, root, dispatch: vi.fn() });
    cleanup();
    expect(root.querySelector("[data-cycle-mount=template]")?.childElementCount).toBe(0);
  });

  it("hides the manual generation action because output updates automatically", () => {
    const root = shell();
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch });
    expect(root.querySelector("button.action, .output-action")).toBeNull();
    expect(dispatch).not.toHaveBeenCalled();
  });
});
