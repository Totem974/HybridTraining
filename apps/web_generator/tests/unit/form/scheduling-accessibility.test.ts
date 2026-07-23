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

  it("reorders sessions with touch Pointer Events", () => {
    const root = shell();
    document.body.append(root);
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "en" });
    const items = root.querySelectorAll<HTMLElement>(".schedule-order__item");

    expect(items[0]?.style.touchAction).toBe("none");
    dispatchPointer(items[0]!, "pointerdown", {
      pointerId: 7,
      pointerType: "touch",
      button: 0,
    });
    expect(items[0]?.classList.contains("is-dragging")).toBe(true);

    dispatchPointer(items[2]!, "pointermove", {
      pointerId: 7,
      pointerType: "touch",
      button: -1,
      clientX: 20,
      clientY: 20,
    });
    expect(items[2]?.classList.contains("is-drag-over")).toBe(true);

    dispatchPointer(items[2]!, "pointerup", {
      pointerId: 7,
      pointerType: "touch",
      button: 0,
      clientX: 20,
      clientY: 20,
    });
    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "schedule-test",
      fieldId: "session-order",
      path: "schedule.sessionOrder",
      value: ["deadlift", "squat", "press"],
    });
    expect(items[0]?.classList.contains("is-dragging")).toBe(false);
    expect(items[2]?.classList.contains("is-drag-over")).toBe(false);
    root.remove();
  });

  it("cancels touch reordering without emitting a partial order", () => {
    const root = shell();
    document.body.append(root);
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "en" });
    const items = root.querySelectorAll<HTMLElement>(".schedule-order__item");

    dispatchPointer(items[0]!, "pointerdown", {
      pointerId: 11,
      pointerType: "pen",
      button: 0,
    });
    dispatchPointer(items[1]!, "pointermove", {
      pointerId: 11,
      pointerType: "pen",
      button: -1,
    });
    dispatchPointer(items[1]!, "pointercancel", {
      pointerId: 11,
      pointerType: "pen",
      button: 0,
    });

    expect(dispatch).not.toHaveBeenCalled();
    expect(root.querySelector(".is-dragging")).toBeNull();
    expect(root.querySelector(".is-drag-over")).toBeNull();
    root.remove();
  });

  it("does not start pointer dragging from a keyboard move button", () => {
    const root = shell();
    document.body.append(root);
    const dispatch = vi.fn();
    renderCycleForm({ schema, root, dispatch, locale: "en" });
    const items = root.querySelectorAll<HTMLElement>(".schedule-order__item");
    const moveButton = items[0]?.querySelector<HTMLButtonElement>(
      ".schedule-token__move:not(:disabled)",
    );

    dispatchPointer(moveButton!, "pointerdown", {
      pointerId: 13,
      pointerType: "touch",
      button: 0,
    });
    dispatchPointer(items[2]!, "pointermove", {
      pointerId: 13,
      pointerType: "touch",
      button: -1,
    });
    dispatchPointer(items[2]!, "pointerup", {
      pointerId: 13,
      pointerType: "touch",
      button: 0,
    });

    expect(dispatch).not.toHaveBeenCalled();
    expect(root.querySelector(".is-dragging")).toBeNull();
    root.remove();
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

function dispatchPointer(
  target: EventTarget,
  type: "pointerdown" | "pointermove" | "pointerup" | "pointercancel",
  init: {
    readonly pointerId: number;
    readonly pointerType: "touch" | "pen" | "mouse";
    readonly button: number;
    readonly clientX?: number;
    readonly clientY?: number;
  },
): void {
  const event = new Event(type, { bubbles: true, cancelable: true });
  for (const [property, value] of Object.entries({
    pointerId: init.pointerId,
    pointerType: init.pointerType,
    button: init.button,
    clientX: init.clientX ?? 0,
    clientY: init.clientY ?? 0,
  })) {
    Object.defineProperty(event, property, { configurable: true, value });
  }
  target.dispatchEvent(event);
}
