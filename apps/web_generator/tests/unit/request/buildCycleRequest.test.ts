import { describe, expect, it } from "vitest";

import { buildCycleRequest } from "../../../src/cycle/request/buildCycleRequest";
import { normalizeEditorState } from "../../../src/cycle/state/editorState";
import type { CycleEditorSchema } from "../../../src/cycle/form/types";

const baseFields: CycleEditorSchema["fields"] = [
  field("template", "templateId", "template", "choice", "template", {
    choices: [{ value: "template", label: "Template" }],
  }),
  field("variant", "variantId", "template", "choice", "variant", {
    choices: [{ value: "variant", label: "Variant" }],
  }),
  field("schedule", "scheduleId", "scheduling", "choice", "schedule", {
    choices: [{ value: "schedule", label: "Schedule" }],
  }),
  field("order", "sessionOrder", "scheduling", "token-order", ["squat_bench"]),
  field("date", "startDate", "scheduling", "date", "2026-07-22"),
  field("mode", "maxMode", "weight", "segmented", "oneRepMax", {
    choices: [{ value: "oneRepMax", label: "1RM" }],
  }),
  field("unit", "unit", "weight", "segmented", "kg", {
    choices: [{ value: "kg", label: "kg" }],
  }),
  field("ratio", "globalTrainingMaxRatioBasisPoints", "weight", "percentage", 9000),
  field("squat", "maxInputs.squat.weight", "weight", "weight", 120),
  field("bench", "maxInputs.bench.weight", "weight", "weight", 90),
  field("bar", "barWeight", "plating", "weight", 20),
  field("plate", "plates.20", "plating", "plate-counter", 2),
  field("warmup", "options.warmup_enabled", "additional-options", "boolean", true),
  field("joker", "options.joker_enabled", "additional-options", "boolean", false),
  field("joker-percentage", "options.joker_percentage", "additional-options", "percentage", 10, {
    minimum: 5,
    maximum: 30,
    enabledWhen: [{ path: "options.joker_enabled", operator: "equals", value: true }],
  }),
  field("title", "programTitle", "output", "text", "My cycle"),
  field("show", "showPlating", "output", "boolean", true),
];

const schema: CycleEditorSchema = {
  apiVersion: "v1",
  schemaVersion: 1,
  engineVersion: "test",
  catalogVersion: 1,
  catalogHash: "hash",
  id: "request-editor",
  templateId: "template",
  variantId: "variant",
  movementIds: ["squat", "bench"],
  sessionIds: ["squat_bench"],
  fields: baseFields,
};

describe("buildCycleRequest", () => {
  it("serializes only active generic schema values with canonical option keys", () => {
    const state = normalizeEditorState(schema);
    const request = buildCycleRequest(state.schema, state.values, { cycleId: "stable" });

    expect(Object.keys(request.maxInputs)).toEqual(["squat", "bench"]);
    expect(request.maxInputs).not.toHaveProperty("squat_bench");
    expect(request.options).toEqual({ warmup_enabled: true, joker_enabled: false });
    expect(request.options).not.toHaveProperty("options.warmup_enabled");
    expect(request.percentageParameters).not.toHaveProperty("joker_percentage");
    expect(request.barProfile.platesPerSide).toHaveLength(2);
    expect(request.startDate).toBe("2026-07-22T00:00:00.000Z");
    expect(request.includeDeload).toBe(false);
  });

  it("nests canonical cycle options and serializes option weights", () => {
    const optionSchema: CycleEditorSchema = {
      ...schema,
      variantId: "original",
      fields: [
        ...baseFields.filter((candidate) => !candidate.path.startsWith("options.")),
        field("warm-up", "options.warmUp.enabled", "additional-options", "boolean", true),
        field("warm-up-type", "options.warmUp.type", "additional-options", "choice", "beyond"),
        field("lower", "options.warmUp.bases.lowerBody", "additional-options", "weight", { centiUnits: 13500, unit: "lb" }),
        field("upper", "options.warmUp.bases.upperBody", "additional-options", "weight", { centiUnits: 9500, unit: "lb" }),
        field("phase", "options.fullBody.phase", "additional-options", "choice", "phase_two"),
        field("deload", "options.deload.enabled", "additional-options", "boolean", true),
      ],
    };
    const state = normalizeEditorState(optionSchema);
    const request = buildCycleRequest(state.schema, state.values);

    expect(request.options).toEqual({
      warmUp: {
        enabled: true,
        type: "beyond",
        bases: {
          lowerBody: { centiUnits: 13500, unit: "kg" },
          upperBody: { centiUnits: 9500, unit: "kg" },
        },
      },
      fullBody: { profile: "original", phase: "phase_two" },
      deload: { enabled: true },
    });
    expect(request.includeDeload).toBe(true);
  });

  it("preserves a forced hidden catalog deload default", () => {
    const forcedDeloadSchema: CycleEditorSchema = {
      ...schema,
      fields: [
        ...baseFields,
        field("forced-deload", "includeDeload", "output", "boolean", true, {
          readOnly: true,
          visibleWhen: [{
            path: "__catalogHiddenOption",
            operator: "equals",
            value: true,
          }],
        }),
      ],
    };
    const state = normalizeEditorState(forcedDeloadSchema);
    const request = buildCycleRequest(state.schema, state.values);

    expect(request.includeDeload).toBe(true);
    expect(request.options).not.toHaveProperty("deload");
  });

  it("includes bounded Joker child only when enabled by schema conditions", () => {
    const initial = normalizeEditorState(schema);
    const enabled = normalizeEditorState(initial.schema, {
      ...initial.values,
      "options.joker_enabled": true,
      "options.joker_percentage": 25,
    });
    const request = buildCycleRequest(enabled.schema, enabled.values);
    expect(request.options).toMatchObject({ joker_enabled: true, joker_percentage: 25 });
    expect(request.percentageParameters).toEqual({ joker_percentage: 25 });
  });

  it("collects generic movement-scoped percentages without polluting options", () => {
    const parameterSchema: CycleEditorSchema = {
      ...schema,
      fields: [
        ...baseFields,
        field(
          "supplemental-global",
          "options.supplemental_ratio",
          "template",
          "percentage",
          5000,
        ),
        field(
          "supplemental-squat",
          "options.supplemental_ratio.squat",
          "template",
          "percentage",
          5500,
        ),
        field(
          "supplemental-bench",
          "options.supplemental_ratio.bench",
          "template",
          "percentage",
          6000,
        ),
      ],
    };
    const state = normalizeEditorState(parameterSchema);
    const request = buildCycleRequest(state.schema, state.values);

    expect(request.percentageParameters).toMatchObject({
      supplemental_ratio: 5000,
    });
    expect(request.percentageParametersByMovement).toEqual({
      squat: { supplemental_ratio: 5500 },
      bench: { supplemental_ratio: 6000 },
    });
    expect(request.options).toMatchObject({ supplemental_ratio: 5000 });
    expect(request.options).not.toHaveProperty("supplemental_ratio.squat");
    expect(request.options).not.toHaveProperty("supplemental_ratio.bench");
  });

  it("ignores inactive and non-movement nested percentages", () => {
    const parameterSchema: CycleEditorSchema = {
      ...schema,
      fields: [
        ...baseFields,
        field("toggle", "options.custom_enabled", "template", "boolean", false),
        field(
          "inactive-squat",
          "options.custom_ratio.squat",
          "template",
          "percentage",
          6500,
          {
            enabledWhen: [{
              path: "options.custom_enabled",
              operator: "equals",
              value: true,
            }],
          },
        ),
        field(
          "nested-common",
          "options.joker.ceilingBasisPoints",
          "additional-options",
          "percentage",
          1000,
        ),
      ],
    };
    const state = normalizeEditorState(parameterSchema);
    const request = buildCycleRequest(state.schema, state.values);

    expect(request.percentageParametersByMovement).toEqual({});
    expect(request.percentageParameters).toMatchObject({
      "joker.ceilingBasisPoints": 1000,
    });
    expect(request.options).toMatchObject({
      custom_enabled: false,
      joker: { ceilingBasisPoints: 1000 },
    });
  });
});

function field(
  id: string,
  path: string,
  region: CycleEditorSchema["fields"][number]["region"],
  kind: CycleEditorSchema["fields"][number]["kind"],
  value: unknown,
  extra: Partial<CycleEditorSchema["fields"][number]> = {},
): CycleEditorSchema["fields"][number] {
  return { id, path, region, kind, label: id, value, ...extra };
}
