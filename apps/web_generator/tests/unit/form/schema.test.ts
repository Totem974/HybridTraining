import { describe, expect, it } from "vitest";

import {
  assertCycleEditorSchema,
  conditionMatches,
  fieldsByRegion,
  localized,
  type CycleEditorSchema,
} from "../../../src/cycle/form";

const schema: CycleEditorSchema = {
  apiVersion: "v1",
  engineVersion: "test",
  catalogVersion: "test",
  catalogHash: "hash",
  schemaVersion: "v1",
  id: "editor",
  fields: [
    {
      id: "mode",
      path: "max.mode",
      region: "weight",
      label: { en: "Mode", fr: "Mode" },
      kind: "segmented",
      value: "one",
      choices: [
        { value: "one", label: "1 RM" },
        { value: "rep", label: "Rep Max" },
      ],
    },
    {
      id: "reps",
      path: "max.reps",
      region: "weight",
      label: "Repetitions",
      kind: "integer",
      value: 3,
      visibleWhen: [{ path: "max.mode", operator: "equals", value: "rep" }],
    },
  ],
};

describe("Cycle form schema", () => {
  it("uses localized catalogue labels with a deterministic fallback", () => {
    expect(localized({ en: "Weight", fr: "Charges" }, "fr-MU")).toBe("Charges");
    expect(localized({ en: "Weight" }, "de")).toBe("Weight");
  });

  it("evaluates visibility against schema values without template rules", () => {
    expect(
      conditionMatches(
        { path: "max.mode", operator: "in", value: ["one", "rep"] },
        { "max.mode": "rep" },
      ),
    ).toBe(true);
    expect(fieldsByRegion(schema, "weight").map((field) => field.id)).toEqual([
      "mode",
    ]);
  });

  it("rejects duplicate public field paths", () => {
    expect(() =>
      assertCycleEditorSchema({
        ...schema,
        fields: [...schema.fields, { ...schema.fields[0]!, id: "other" }],
      }),
    ).toThrow("Duplicate Cycle field path");
  });
});
