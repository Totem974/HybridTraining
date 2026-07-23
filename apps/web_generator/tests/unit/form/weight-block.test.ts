import { beforeEach, describe, expect, it, vi } from "vitest";

import { renderWeightBlock } from "../../../src/cycle/form/blocks/weight";
import type { CycleEditorField } from "../../../src/cycle/form/types";

const movements = [
  ["overhead_press", "Overhead Press"],
  ["deadlift", "Deadlift"],
  ["bench_press", "Bench Press"],
  ["squat", "Squat"],
] as const;

function fields(mode: string): CycleEditorField[] {
  return [
    {
      id: "max-mode",
      path: "maxMode",
      region: "weight",
      kind: "segmented",
      label: "Maximum type",
      value: mode,
      choices: [
        { value: "oneRepMax", label: "1 Rep Max" },
        { value: "onePlusSet", label: "1+ Set" },
        { value: "directTrainingMax", label: "Training Max" },
        { value: "repMax", label: "Rep Max" },
      ],
    },
    {
      id: "ratio",
      path: "globalTrainingMaxRatioBasisPoints",
      region: "weight",
      kind: "percentage",
      label: "Training Max ratio",
      value: 9000,
      minimum: 1000,
      maximum: 10000,
      step: 50,
    },
    ...movements.flatMap(([id, label]) => [
      {
        id: `load-${id}`,
        path: `maxInputs.${id}.weight`,
        region: "weight" as const,
        kind: "weight" as const,
        label,
        value: 100,
        minimum: 0,
        step: 0.5,
      },
      {
        id: `reps-${id}`,
        path: `maxInputs.${id}.repetitions`,
        region: "weight" as const,
        kind: "integer" as const,
        label: "Repetitions",
        value: 5,
        minimum: 1,
        maximum: 20,
        visibleWhen: [{ path: "maxMode", operator: "equals" as const, value: "repMax" }],
      },
    ]),
    {
      id: "unit",
      path: "unit",
      region: "weight",
      kind: "segmented",
      label: "Unit",
      value: "kg",
      choices: [
        { value: "kg", label: "kg" },
        { value: "lb", label: "lb" },
      ],
    },
  ];
}

function render(mode = "oneRepMax") {
  const schemaFields = fields(mode);
  const dispatch = vi.fn();
  const result = renderWeightBlock({
    fields: schemaFields,
    values: Object.fromEntries(schemaFields.map((field) => [field.path, field.value])),
    locale: "en",
    schemaId: "cycle-editor",
    dispatch,
  });
  document.body.append(result);
  return { result, dispatch };
}

describe("Weight block", () => {
  beforeEach(() => document.body.replaceChildren());

  it("renders the full-width selector and four aligned one-rep rows", () => {
    const { result } = render();

    expect(
      [...result.querySelectorAll(".weight-mode label")].map((label) => label.textContent),
    ).toEqual(["1 Rep Max", "1+ Set", "Training Max", "Rep Max"]);
    expect(
      result.querySelector<HTMLElement>(".weight-mode .segmented-control")
        ?.style.getPropertyValue("--weight-choice-count"),
    ).toBe("4");
    expect(result.querySelectorAll(".weight-movement")).toHaveLength(4);
    expect(result.querySelectorAll(".weight-repetitions--fixed")).toHaveLength(4);
    expect(
      [...result.querySelectorAll(".weight-repetitions--fixed")].map(
        (repetitions) => repetitions.textContent,
      ),
    ).toEqual(["1", "1", "1", "1"]);
    expect(
      result.querySelector<HTMLInputElement>(".weight-ratio__input")?.value,
    ).toBe("90");
    expect(result.lastElementChild?.classList.contains("weight-unit")).toBe(true);
  });

  it("renders onePlusSet as a fixed 1+ rep and hides the global ratio", () => {
    const { result } = render("onePlusSet");

    expect(result.querySelectorAll("input.weight-repetitions")).toHaveLength(0);
    expect(
      [...result.querySelectorAll(".weight-repetitions--fixed")].map(
        (repetitions) => repetitions.textContent,
      ),
    ).toEqual(["1+", "1+", "1+", "1+"]);
    expect(result.querySelector(".weight-ratio")).toBeNull();
  });

  it("shows editable repetitions and the TM ratio for a rep max", () => {
    const { result } = render("repMax");

    expect(result.querySelectorAll("input.weight-repetitions")).toHaveLength(4);
    expect(
      result.querySelector<HTMLInputElement>(".weight-ratio__input")?.value,
    ).toBe("90");
  });

  it("keeps direct Training Max rows free of per-movement ratios", () => {
    const { result } = render("directTrainingMax");
    expect(result.querySelectorAll(".weight-repetitions")).toHaveLength(0);
    expect(result.querySelector(".weight-ratio")).toBeNull();
    expect(result.textContent).not.toContain("maxInputs");
  });

  it("dispatches schema paths and preserves basis points", () => {
    const { result, dispatch } = render();
    const ratio = result.querySelector<HTMLInputElement>(".weight-ratio__input")!;
    ratio.value = "87.5";
    ratio.dispatchEvent(new Event("change"));

    expect(dispatch).toHaveBeenCalledWith({
      type: "cycle.field.changed",
      schemaId: "cycle-editor",
      fieldId: "ratio",
      path: "globalTrainingMaxRatioBasisPoints",
      value: 8750,
    });
  });
});
