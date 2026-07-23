import {
  fieldIsEnabled,
  fieldIsVisible,
} from "../form/schema";
import type {
  CycleEditorField,
  CycleEditorSchema,
  JsonValue,
} from "../form/types";

export type CycleEditorValues = Record<string, JsonValue>;

export interface NormalizedEditorState {
  readonly schema: CycleEditorSchema;
  readonly values: CycleEditorValues;
  readonly defaults: CycleEditorValues;
}

/**
 * Merges values into an engine schema and converges all conditional children
 * back to their schema defaults. It intentionally knows no template IDs.
 */
export function normalizeEditorState(
  source: CycleEditorSchema,
  candidates: Readonly<Record<string, JsonValue>> = {},
  authoritativePaths: ReadonlySet<string> = new Set(),
  sourceDefaults?: Readonly<Record<string, JsonValue>>,
): NormalizedEditorState {
  const defaults = Object.fromEntries(
    source.fields.map((field) => [
      field.path,
      structuredClone(
        field.readOnly ? field.value : sourceDefaults?.[field.path] ?? field.value,
      ),
    ]),
  ) as CycleEditorValues;
  const values: CycleEditorValues = { ...defaults };

  for (const field of source.fields) {
    if (authoritativePaths.has(field.path)) continue;
    const candidate = candidates[field.path];
    if (candidate !== undefined && isAllowedValue(field, candidate)) {
      values[field.path] = structuredClone(candidate);
    }
  }

  // Resetting one child can invalidate another child. Converge generically.
  for (let pass = 0; pass <= source.fields.length; pass += 1) {
    let changed = false;
    for (const field of source.fields) {
      if (fieldIsVisible(field, values) && (field.readOnly || fieldIsEnabled(field, values))) {
        continue;
      }
      const defaultValue = defaults[field.path];
      if (!sameValue(values[field.path], defaultValue)) {
        values[field.path] = structuredClone(defaultValue);
        changed = true;
      }
    }
    if (!changed) break;
  }

  return {
    defaults,
    values,
    schema: {
      ...source,
      fields: source.fields.map((field) => ({
        ...field,
        value: structuredClone(values[field.path]),
      })),
    },
  };
}

export function changeEditorValue(
  state: NormalizedEditorState,
  path: string,
  value: JsonValue,
): NormalizedEditorState {
  const field = state.schema.fields.find((candidate) => candidate.path === path);
  if (!field) return state;
  const candidate = isAllowedValue(field, value) ? value : state.defaults[path];
  return normalizeEditorState(
    state.schema,
    { ...state.values, [path]: candidate },
    new Set(),
    state.defaults,
  );
}

export function activeSchemaFields(
  schema: CycleEditorSchema,
  values: Readonly<Record<string, JsonValue>>,
): readonly CycleEditorField[] {
  return schema.fields.filter(
    (field) => fieldIsVisible(field, values) && (field.readOnly || fieldIsEnabled(field, values)),
  );
}

function isAllowedValue(field: CycleEditorField, value: JsonValue): boolean {
  if (field.kind === "token-order") {
    return isCompleteTokenOrder(field, value);
  }
  if (field.choices?.length) {
    return field.choices.some((choice) => sameValue(choice.value, value));
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) return false;
    if (field.minimum !== undefined && value < field.minimum) return false;
    if (field.maximum !== undefined && value > field.maximum) return false;
  }
  return switchKind(field, value);
}

function isCompleteTokenOrder(
  field: CycleEditorField,
  value: JsonValue,
): boolean {
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string")) {
    return false;
  }
  const choiceTokens = field.choices?.map((choice) => choice.value);
  const expected = choiceTokens?.length ? choiceTokens : field.value;
  if (
    !Array.isArray(expected) ||
    !expected.every((item) => typeof item === "string")
  ) {
    return false;
  }
  const expectedTokens = expected as readonly string[];
  const candidateTokens = value as readonly string[];
  const expectedSet = new Set(expectedTokens);
  const candidateSet = new Set(candidateTokens);
  return expectedSet.size === expectedTokens.length &&
    candidateSet.size === candidateTokens.length &&
    candidateTokens.length === expectedTokens.length &&
    candidateTokens.every((token) => expectedSet.has(token));
}

function switchKind(field: CycleEditorField, value: JsonValue): boolean {
  switch (field.kind) {
    case "boolean":
      return typeof value === "boolean";
    case "integer":
    case "plate-counter":
      return typeof value === "number" && Number.isInteger(value);
    case "decimal":
    case "percentage":
    case "weight":
      return typeof value === "number" && Number.isFinite(value);
    case "token-order":
      return false;
    case "date":
    case "text":
      return typeof value === "string";
    case "action":
      return true;
    case "choice":
    case "segmented":
      return value !== undefined;
  }
}

function sameValue(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}
