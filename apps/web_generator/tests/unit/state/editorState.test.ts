import { describe, expect, it } from "vitest";

import {
  activeSchemaFields,
  changeEditorValue,
  normalizeEditorState,
} from "../../../src/cycle/state/editorState";
import type { CycleEditorSchema } from "../../../src/cycle/form/types";

const schema: CycleEditorSchema = {
  apiVersion: "v1",
  schemaVersion: 1,
  engineVersion: "test",
  catalogVersion: 1,
  catalogHash: "hash",
  id: "conditional-editor",
  templateId: "template",
  variantId: "variant",
  movementIds: [],
  sessionIds: [],
  fields: [
    {
      id: "joker-enabled",
      path: "options.joker_enabled",
      region: "additional-options",
      kind: "boolean",
      label: "Joker",
      value: false,
    },
    {
      id: "joker-percentage",
      path: "options.joker_percentage",
      region: "additional-options",
      kind: "percentage",
      label: "Joker percentage",
      value: 10,
      minimum: 5,
      maximum: 30,
      enabledWhen: [{
        path: "options.joker_enabled",
        operator: "equals",
        value: true,
      }],
    },
    {
      id: "deload-type",
      path: "options.deload_type",
      region: "additional-options",
      kind: "choice",
      label: "Deload",
      value: "original",
      choices: [
        { value: "original", label: "Original" },
        { value: "skip", label: "Skip" },
      ],
    },
    {
      id: "deload-skip-weeks",
      path: "options.deload_skip_weeks",
      region: "additional-options",
      kind: "integer",
      label: "Skip weeks",
      value: 1,
      visibleWhen: [{
        path: "options.deload_type",
        operator: "equals",
        value: "skip",
      }],
    },
  ],
};

describe("generic Cycle editor state", () => {
  it("purges conditional children when their parent changes", () => {
    const enabled = normalizeEditorState(schema, {
      "options.joker_enabled": true,
      "options.joker_percentage": 25,
      "options.deload_type": "skip",
      "options.deload_skip_weeks": 3,
    });
    expect(enabled.values["options.joker_percentage"]).toBe(25);
    expect(enabled.values["options.deload_skip_weeks"]).toBe(3);

    const jokerDisabled = changeEditorValue(
      enabled,
      "options.joker_enabled",
      false,
    );
    expect(jokerDisabled.values["options.joker_percentage"]).toBe(10);
    expect(activeSchemaFields(jokerDisabled.schema, jokerDisabled.values)
      .map((field) => field.path)).not.toContain("options.joker_percentage");

    const deloadOriginal = changeEditorValue(
      jokerDisabled,
      "options.deload_type",
      "original",
    );
    expect(deloadOriginal.values["options.deload_skip_weeks"]).toBe(1);
    expect(activeSchemaFields(deloadOriginal.schema, deloadOriginal.values)
      .map((field) => field.path)).not.toContain("options.deload_skip_weeks");
  });

  it("rejects preserved values outside new choices and numeric bounds", () => {
    const normalized = normalizeEditorState(schema, {
      "options.deload_type": "unknown",
      "options.joker_enabled": true,
      "options.joker_percentage": 31,
    });
    expect(normalized.values["options.deload_type"]).toBe("original");
    expect(normalized.values["options.joker_percentage"]).toBe(10);
  });

  it("keeps catalog-owned read-only defaults authoritative across schemas", () => {
    const forcedSchema: CycleEditorSchema = {
      ...schema,
      fields: [
        ...schema.fields,
        {
          id: "forced-deload",
          path: "includeDeload",
          region: "output",
          kind: "boolean",
          label: "Deload",
          value: true,
          readOnly: true,
        },
      ],
    };
    const normalized = normalizeEditorState(
      forcedSchema,
      {},
      new Set(),
      { includeDeload: false },
    );

    expect(normalized.values.includeDeload).toBe(true);
  });
});
