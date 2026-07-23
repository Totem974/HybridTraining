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

  it("supports drag and drop while preserving keyboard controls", () => {
    const root = shell();
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "en" });
    const items = root.querySelectorAll<HTMLElement>(".schedule-order__item");
    const transfer = new MemoryDataTransfer();
    const dragStart = new Event("dragstart", { bubbles: true, cancelable: true });
    Object.defineProperty(dragStart, "dataTransfer", { value: transfer });
    items[0]?.dispatchEvent(dragStart);
    const drop = new Event("drop", { bubbles: true, cancelable: true });
    Object.defineProperty(drop, "dataTransfer", { value: transfer });
    items[2]?.dispatchEvent(drop);

    expect(items[0]?.draggable).toBe(true);
    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "schedule-test",
      fieldId: "session-order",
      path: "schedule.sessionOrder",
      value: ["deadlift", "squat", "press"],
    });
  });
});

class MemoryDataTransfer {
  effectAllowed = "uninitialized";
  dropEffect = "none";
  private value = "";

  setData(_format: string, value: string): void {
    this.value = value;
  }

  getData(_format: string): string {
    return this.value;
  }
}
