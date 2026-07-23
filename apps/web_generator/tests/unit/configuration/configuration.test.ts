import { describe, expect, it } from "vitest";

import type { CycleEditorSchema } from "../../../src/cycle/form/types";
import {
  cycleConfigurationToCycleRequest,
  cycleConfigurationToEditorValues,
  editorValuesToCycleConfiguration,
  migrateCycleRequestV1ToConfiguration,
} from "../../../src/cycle/configuration";
import { normalizeEditorState } from "../../../src/cycle/state/editorState";

describe("CycleConfiguration codec", () => {
  it("round-trips nested template and common options without template knowledge", () => {
    const schema = makeSchema("kg");
    const state = normalizeEditorState(schema, {
      "options.fullBody.phase": "phase_two",
      "options.warmUp.enabled": true,
      "options.warmUp.type": "beyond",
      "options.warmUp.bases.lowerBody": 135,
      "options.warmUp.bases.upperBody": 95,
      "options.joker.enabled": true,
      "options.joker.ceilingBasisPoints": 1500,
      "options.deload.enabled": true,
      "options.deload.type": "deload3",
      "options.deload.skipWarmUp": true,
    });

    const configuration = editorValuesToCycleConfiguration(schema, state.values, metadata);
    expect(configuration.template.options).toEqual({
      fullBody: { profile: "original", phase: "phase_two" },
    });
    expect(configuration.commonOptions).toMatchObject({
      warmUp: { enabled: true, type: "beyond" },
      joker: { enabled: true, ceilingBasisPoints: 1500 },
      deload: { enabled: true, type: "deload3", skipWarmUp: true },
    });
    expect(cycleConfigurationToEditorValues(configuration, schema)).toMatchObject({
      "options.fullBody.phase": "phase_two",
      "options.warmUp.bases.lowerBody": 135,
      "options.joker.ceilingBasisPoints": 1500,
    });
  });

  it.each(["kg", "lb"] as const)("preserves centi-unit equipment in %s", (unit) => {
    const schema = makeSchema(unit);
    const values = normalizeEditorState(schema, {
      unit,
      barWeight: 45.5,
      "plates.20": 3,
      "maxInputs.squat.weight": 123.45,
    }).values;
    const configuration = editorValuesToCycleConfiguration(schema, values, metadata);
    expect(configuration.maxes.values.squat?.weight).toEqual({ centiUnits: 12345, unit });
    expect("bar" in configuration.equipment && configuration.equipment.bar.weight)
      .toEqual({ centiUnits: 4550, unit });
    const restored = cycleConfigurationToEditorValues(configuration, schema);
    expect(restored["plates.20"]).toBe(3);
    expect(restored["maxInputs.squat.weight"]).toBe(123.45);
  });

  it("preserves rep-max repetitions and formula through request conversion", () => {
    const schema = makeSchema("kg", "repMax");
    const state = normalizeEditorState(schema, {
      maxMode: "repMax",
      "maxInputs.squat.weight": 110,
      "maxInputs.squat.repetitions": 7,
    });
    const configuration = editorValuesToCycleConfiguration(schema, state.values, metadata);
    const request = cycleConfigurationToCycleRequest(configuration, schema, { cycleId: "roundtrip" });
    expect(request.maxInputs.squat).toEqual({
      type: "repMax",
      weight: { centiUnits: 11000, unit: "kg" },
      repetitions: 7,
      formula: "epley",
    });
    expect(request.cycleId).toBe("roundtrip");
  });

  it("migrates an existing v1 request without losing execution data", () => {
    const schema = makeSchema("lb", "repMax");
    const state = normalizeEditorState(schema, { unit: "lb", maxMode: "repMax" });
    const original = cycleConfigurationToCycleRequest(
      editorValuesToCycleConfiguration(schema, state.values, metadata),
      schema,
      { cycleId: "legacy-cycle" },
    );
    const migrated = migrateCycleRequestV1ToConfiguration(original, metadata);
    const restored = cycleConfigurationToCycleRequest(migrated, schema, { cycleId: original.cycleId });
    expect(restored).toEqual(original);
  });
});

const metadata = { catalogVersion: 42, catalogHash: "catalog-hash" };

function makeSchema(
  unit: "kg" | "lb",
  mode: "oneRepMax" | "repMax" = "oneRepMax",
): CycleEditorSchema {
  const fields: CycleEditorSchema["fields"] = [
    field("templateId", "template", "choice", "full_body", ["full_body"]),
    field("variantId", "template", "choice", "original", ["original"]),
    field("scheduleId", "scheduling", "choice", "three_day", ["three_day"]),
    field("sessionOrder", "scheduling", "token-order", ["squat"]),
    field("startDate", "scheduling", "date", "2026-07-27"),
    field("maxMode", "weight", "segmented", mode, ["oneRepMax", "repMax"]),
    field("unit", "weight", "segmented", unit, ["kg", "lb"]),
    field("globalTrainingMaxRatioBasisPoints", "weight", "percentage", 9000),
    field("maxInputs.squat.weight", "weight", "weight", 120),
    field("maxInputs.squat.repetitions", "weight", "integer", 5),
    field("barWeight", "plating", "weight", unit === "kg" ? 20 : 45),
    field("plates.20", "plating", "plate-counter", 2),
    field("options.fullBody.phase", "template", "choice", "phase_one", ["phase_one", "phase_two"]),
    field("options.warmUp.enabled", "additional-options", "boolean", true),
    field("options.warmUp.type", "additional-options", "choice", "beyond", ["original", "beyond"]),
    field("options.warmUp.bases.lowerBody", "additional-options", "weight", 135),
    field("options.warmUp.bases.upperBody", "additional-options", "weight", 95),
    field("options.joker.enabled", "additional-options", "boolean", true),
    field("options.joker.ceilingBasisPoints", "additional-options", "percentage", 500),
    field("options.deload.enabled", "additional-options", "boolean", true),
    field("options.deload.type", "additional-options", "choice", "deload1", ["deload1", "deload3"]),
    field("options.deload.skipWarmUp", "additional-options", "boolean", false),
    field("programTitle", "output", "text", "Cycle"),
    field("showPlating", "output", "boolean", true),
  ];
  return {
    apiVersion: "v1",
    schemaVersion: 1,
    engineVersion: "test",
    catalogVersion: metadata.catalogVersion,
    catalogHash: metadata.catalogHash,
    id: "editor",
    templateId: "full_body",
    variantId: "original",
    movementIds: ["squat"],
    sessionIds: ["squat"],
    fields,
  };
}

function field(
  path: string,
  region: CycleEditorSchema["fields"][number]["region"],
  kind: CycleEditorSchema["fields"][number]["kind"],
  value: unknown,
  choices?: readonly unknown[],
): CycleEditorSchema["fields"][number] {
  return {
    id: path,
    path,
    region,
    kind,
    label: path,
    value,
    ...(choices === undefined
      ? {}
      : { choices: choices.map((choice) => ({ value: choice, label: String(choice) })) }),
  };
}
