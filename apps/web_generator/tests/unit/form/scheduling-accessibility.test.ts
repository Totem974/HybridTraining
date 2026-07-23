// @vitest-environment jsdom
import { describe, expect, it, vi } from "vitest";

import {
  renderCycleForm,
  type CycleEditorSchema,
} from "../../../src/cycle/form";

function shell(): HTMLElement {
  const root = document.createElement("main");
  for (const region of [
    "weight",
    "template",
    "additional-options",
    "plating",
    "scheduling",
    "output",
  ]) {
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
  id: "schedule-test",
  templateId: "standard",
  variantId: "default",
  movementIds: [],
  sessionIds: ["press", "deadlift", "squat"],
  fields: [{
    id: "session-order",
    path: "schedule.sessionOrder",
    region: "scheduling",
    label: { en: "Session order", fr: "Ordre des séances" },
    kind: "token-order",
    value: ["press", "deadlift", "squat"],
    choices: [
      { value: "press", label: { en: "Press", fr: "Développé" } },
      { value: "deadlift", label: { en: "Deadlift", fr: "Soulevé de terre" } },
      { value: "squat", label: "Squat" },
    ],
  }],
};

describe("Scheduling accessibility", () => {
  it("offers explicit keyboard buttons and disables moves at both boundaries", () => {
    const root = shell();
    renderCycleForm({ schema, root, dispatch: vi.fn(), locale: "en" });

    const left = root.querySelectorAll<HTMLButtonElement>('button[aria-label$="left"]');
    const right = root.querySelectorAll<HTMLButtonElement>('button[aria-label$="right"]');
    expect(left).toHaveLength(3);
    expect(right).toHaveLength(3);
    expect(left[0]?.disabled).toBe(true);
    expect(right[2]?.disabled).toBe(true);
    expect(right[0]?.disabled).toBe(false);
  });

  it("localizes controls and emits the reordered session list", () => {
    const root = shell();
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "fr" });

    const moveRight = root.querySelector<HTMLButtonElement>(
      'button[aria-label="Déplacer Développé vers la droite"]',
    );
    expect(moveRight).not.toBeNull();
    moveRight?.click();
    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "schedule-test",
      fieldId: "session-order",
      path: "schedule.sessionOrder",
      value: ["deadlift", "press", "squat"],
    });
  });
});
