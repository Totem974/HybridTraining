import type {
  CycleRequest,
  CycleRequestMaxInput,
} from "../../../../../contracts/v1/generated/contracts";
import type {
  CycleEditorSchema,
  JsonValue,
} from "../form/types";
import { activeSchemaFields } from "../state/editorState";

export interface BuildCycleRequestOptions {
  readonly cycleId?: string;
}

export function buildCycleRequest(
  schema: CycleEditorSchema,
  values: Readonly<Record<string, JsonValue>>,
  options: BuildCycleRequestOptions = {},
): CycleRequest {
  const active = activeSchemaFields(schema, values);
  const activePaths = new Set(active.map((field) => field.path));
  const unit = values.unit === "lb" ? "lb" : "kg";
  const sessionOrder = stringList(values.sessionOrder);
  if (sessionOrder.length === 0) throw new Error("SESSION_ORDER_REQUIRED");

  const maxMode = stringValue(values.maxMode, "oneRepMax") as CycleRequestMaxInput["type"];
  const maxInputs = Object.fromEntries(schema.movementIds.map((movement) => {
    const input: CycleRequestMaxInput = {
      type: maxMode,
      weight: weight(numberValue(values, `maxInputs.${movement}.weight`, 100), unit),
      ...(maxMode === "repMax"
        ? {
            repetitions: Math.round(numberValue(values, `maxInputs.${movement}.repetitions`, 5)),
            formula: "epley",
          }
        : {}),
    };
    return [movement, input];
  }));

  const optionFields = active.filter((field) => field.path.startsWith("options."));
  const movementIds = new Set(schema.movementIds);
  const movementPercentageFields = new Map(
    optionFields.flatMap((field) => {
      const scope = movementPercentageScope(field.path, field.kind, movementIds);
      return scope ? [[field.path, scope] as const] : [];
    }),
  );
  const optionValues: Record<string, unknown> = {};
  for (const field of optionFields) {
    // Movement-scoped percentages belong to the compiler parameter map, not
    // Cycle options. This keeps the options contract free of catalog-specific
    // parameter names.
    if (movementPercentageFields.has(field.path)) continue;
    const path = field.path.slice("options.".length);
    const rawValue = values[field.path];
    const value = field.kind === "weight"
      ? typeof rawValue === "number"
        ? weight(rawValue, unit)
        : isRecord(rawValue) && typeof rawValue.centiUnits === "number"
          ? { centiUnits: Math.round(rawValue.centiUnits), unit }
          : rawValue
      : rawValue;
    setNested(optionValues, path, value);
  }
  if (isRecord(optionValues.fullBody)) {
    optionValues.fullBody.profile = schema.variantId;
  }
  const percentageParameters = Object.fromEntries(optionFields
    .filter((field) =>
      field.kind === "percentage" &&
      !movementPercentageFields.has(field.path) &&
      typeof values[field.path] === "number"
    )
    .map((field) => [field.path.slice("options.".length), Math.round(values[field.path] as number)]));
  const percentageParametersByMovement: Record<string, Record<string, number>> = {};
  for (const field of optionFields) {
    const scope = movementPercentageFields.get(field.path);
    const value = values[field.path];
    if (!scope || typeof value !== "number" || !Number.isFinite(value)) continue;
    (percentageParametersByMovement[scope.movementId] ??= {})[scope.parameterId] =
      Math.round(value);
  }

  const platesPerSide = active
    .filter((field) => field.path.startsWith("plates."))
    .flatMap((field) => {
      const count = values[field.path];
      const denomination = Number(field.path.slice("plates.".length));
      if (typeof count !== "number" || count <= 0 || !Number.isFinite(denomination)) return [];
      return Array.from({ length: Math.round(count) }, () => weight(denomination, unit));
    });

  const startDate = stringValue(values.startDate, "");
  return {
    apiVersion: "v1",
    schemaVersion: 1,
    cycleId: options.cycleId ?? stableCycleId(schema, startDate),
    templateId: stringValue(values.templateId, schema.templateId),
    variantId: stringValue(values.variantId, schema.variantId),
    ...(typeof values.scheduleId === "string" ? { scheduleId: values.scheduleId } : {}),
    startDate: startDate.includes("T") ? startDate : `${startDate}T00:00:00.000Z`,
    sessionOrder,
    maxInputs,
    globalTrainingMaxRatioBasisPoints: Math.round(
      numberValue(values, "globalTrainingMaxRatioBasisPoints", 9000),
    ),
    trainingMaxRatioByMovement: {},
    percentageParameters,
    percentageParametersByMovement,
    options: optionValues,
    unit,
    barProfile: {
      weight: weight(numberValue(values, "barWeight", 20), unit),
      platesPerSide,
    },
    includeDeload: activePaths.has("options.deload.enabled")
      ? values["options.deload.enabled"] === true
      : false,
    programTitle: stringValue(values.programTitle, "5/3/1"),
    showPlating: values.showPlating === true,
  };
}

function movementPercentageScope(
  path: string,
  kind: CycleEditorSchema["fields"][number]["kind"],
  movementIds: ReadonlySet<string>,
): { readonly parameterId: string; readonly movementId: string } | undefined {
  if (kind !== "percentage") return undefined;
  const segments = path.split(".");
  if (
    segments.length !== 3 ||
    segments[0] !== "options" ||
    segments[1] === "" ||
    !movementIds.has(segments[2]!)
  ) {
    return undefined;
  }
  return { parameterId: segments[1]!, movementId: segments[2]! };
}

function stableCycleId(schema: CycleEditorSchema, startDate: string): string {
  return `cycle-${schema.templateId}-${schema.variantId}-${startDate || "unscheduled"}`;
}

function weight(value: number, unit: "kg" | "lb") {
  return { centiUnits: Math.round(value * 100), unit } as const;
}

function numberValue(
  values: Readonly<Record<string, JsonValue>>,
  path: string,
  fallback: number,
): number {
  const value = values[path];
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function stringValue(value: JsonValue | undefined, fallback: string): string {
  return typeof value === "string" ? value : fallback;
}

function stringList(value: JsonValue | undefined): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function setNested(target: Record<string, unknown>, path: string, value: unknown): void {
  const segments = path.split(".").filter(Boolean);
  let cursor = target;
  for (const segment of segments.slice(0, -1)) {
    const existing = cursor[segment];
    if (!isRecord(existing)) cursor[segment] = {};
    cursor = cursor[segment] as Record<string, unknown>;
  }
  if (segments.length > 0) cursor[segments.at(-1)!] = value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
