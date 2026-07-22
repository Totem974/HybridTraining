import type {
  CycleEditorCondition,
  CycleEditorField,
  CycleEditorSchema,
  CycleFormRegion,
  JsonValue,
  LocalizedText,
} from "./types";

export const cycleFormRegions: readonly CycleFormRegion[] = [
  "weight",
  "template",
  "additional-options",
  "plating",
  "scheduling",
  "output",
];

export function localized(text: LocalizedText, locale: string): string {
  if (typeof text === "string") return text;
  const language = locale.toLowerCase().split("-")[0] ?? locale;
  return text[locale] ?? text[language] ?? text.en ?? Object.values(text)[0] ?? "";
}

export function readPath(
  values: Readonly<Record<string, JsonValue>>,
  path: string,
): JsonValue | undefined {
  const exact = values[path];
  if (exact !== undefined) return exact;
  const parts = path.split(".").filter(Boolean);
  let cursor: JsonValue | undefined = values;
  for (const part of parts) {
    if (cursor === null || typeof cursor !== "object" || Array.isArray(cursor)) {
      return undefined;
    }
    cursor = cursor[part];
  }
  return cursor;
}

function equals(left: JsonValue | undefined, right: JsonValue | undefined): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function conditionMatches(
  condition: CycleEditorCondition,
  values: Readonly<Record<string, JsonValue>>,
): boolean {
  const actual = readPath(values, condition.path);
  switch (condition.operator) {
    case "equals":
      return equals(actual, condition.value);
    case "notEquals":
      return !equals(actual, condition.value);
    case "present":
      return actual !== undefined && actual !== null && actual !== "";
    case "in":
      return Array.isArray(condition.value) &&
        condition.value.some((candidate) => equals(actual, candidate));
    case "greaterThanOrEqual":
      return typeof actual === "number" &&
        typeof condition.value === "number" &&
        actual >= condition.value;
    case "lessThanOrEqual":
      return typeof actual === "number" &&
        typeof condition.value === "number" &&
        actual <= condition.value;
  }
}

export function fieldIsVisible(
  field: CycleEditorField,
  values: Readonly<Record<string, JsonValue>>,
): boolean {
  return (field.visibleWhen ?? []).every((condition) =>
    conditionMatches(condition, values),
  );
}

export function fieldIsEnabled(
  field: CycleEditorField,
  values: Readonly<Record<string, JsonValue>>,
): boolean {
  return !field.readOnly &&
    (field.enabledWhen ?? []).every((condition) =>
      conditionMatches(condition, values),
    );
}

export function valuesFromSchema(
  schema: CycleEditorSchema,
): Readonly<Record<string, JsonValue>> {
  return Object.fromEntries(schema.fields.map((field) => [field.path, field.value]));
}

export function fieldsByRegion(
  schema: CycleEditorSchema,
  region: CycleFormRegion,
): readonly CycleEditorField[] {
  const values = valuesFromSchema(schema);
  return schema.fields.filter(
    (field) => field.region === region && fieldIsVisible(field, values),
  );
}

export function assertCycleEditorSchema(schema: CycleEditorSchema): void {
  const ids = new Set<string>();
  const paths = new Set<string>();
  for (const field of schema.fields) {
    if (!cycleFormRegions.includes(field.region)) {
      throw new Error(`Unsupported Cycle form region: ${String(field.region)}`);
    }
    if (ids.has(field.id)) throw new Error(`Duplicate Cycle field id: ${field.id}`);
    if (paths.has(field.path)) throw new Error(`Duplicate Cycle field path: ${field.path}`);
    ids.add(field.id);
    paths.add(field.path);
    if (
      (field.kind === "choice" || field.kind === "segmented") &&
      (!field.choices || field.choices.length === 0)
    ) {
      throw new Error(`Cycle field ${field.id} requires schema choices`);
    }
    if (field.kind === "plate-counter" && typeof field.value !== "number") {
      throw new Error(`Cycle plate counter ${field.id} requires a numeric value`);
    }
    if (field.kind === "token-order" && !Array.isArray(field.value)) {
      throw new Error(`Cycle token order ${field.id} requires an array value`);
    }
    if (field.kind === "action" && !field.action) {
      throw new Error(`Cycle action ${field.id} requires an action identifier`);
    }
  }
}
