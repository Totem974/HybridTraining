import type {
  CycleConfiguration,
  CycleRequest,
  Weight,
} from "../../../../../contracts/v1/generated/contracts";
export type { CycleConfiguration } from "../../../../../contracts/v1/generated/contracts";
import type { CycleEditorSchema, JsonValue } from "../form/types";
import { buildCycleRequest, type BuildCycleRequestOptions } from "../request/buildCycleRequest";

export interface CatalogMetadata {
  readonly catalogVersion: number;
  readonly catalogHash: string;
}

const commonOptionNames = new Set(["warmUp", "joker", "deload"]);

export function editorValuesToCycleConfiguration(
  schema: CycleEditorSchema,
  values: Readonly<Record<string, JsonValue>>,
  catalog: CatalogMetadata = schema,
): CycleConfiguration {
  const request = buildCycleRequest(schema, values);
  return cycleRequestToConfiguration(request, catalog);
}

export function cycleConfigurationToEditorValues(
  configuration: CycleConfiguration,
  schema?: CycleEditorSchema,
): Record<string, JsonValue> {
  const unit = configuration.equipment.unit;
  const values: Record<string, JsonValue> = {
    templateId: configuration.template.id,
    variantId: configuration.template.variantId,
    maxMode: configuration.maxes.mode,
    globalTrainingMaxRatioBasisPoints:
      configuration.maxes.globalTrainingMaxRatioBasisPoints,
    unit,
    scheduleId: configuration.schedule.id,
    startDate: configuration.schedule.startDate.slice(0, 10),
    sessionOrder: [...configuration.schedule.sessionOrder],
    programTitle: configuration.output.title,
    showPlating: configuration.output.showPlating,
  };

  for (const [movement, input] of Object.entries(configuration.maxes.values)) {
    values[`maxInputs.${movement}.weight`] = input.weight.centiUnits / 100;
    if ("repetitions" in input && input.repetitions !== undefined) {
      values[`maxInputs.${movement}.repetitions`] = input.repetitions;
    }
  }

  flattenOptions(values, configuration.template.options);
  flattenOptions(values, configuration.commonOptions);

  if ("bar" in configuration.equipment) {
    values.barWeight = configuration.equipment.bar.weight.centiUnits / 100;
    const counts = new Map<number, number>();
    for (const plate of configuration.equipment.bar.platesPerSide) {
      const denomination = plate.centiUnits / 100;
      counts.set(denomination, (counts.get(denomination) ?? 0) + 1);
    }
    for (const [denomination, count] of counts) {
      values[`plates.${denomination}`] = count;
    }
  }

  if (configuration.schedule.trainingDays !== undefined) {
    values.trainingDays = [...configuration.schedule.trainingDays];
  }
  if (configuration.maxes.ratiosByMovement !== undefined) {
    for (const [movement, ratio] of Object.entries(configuration.maxes.ratiosByMovement)) {
      values[`trainingMaxRatioByMovement.${movement}`] = ratio;
    }
  }

  if (schema) {
    for (const field of schema.fields) {
      const value = values[field.path];
      if (field.kind === "weight" && isWeight(value)) {
        values[field.path] = value.centiUnits / 100;
      }
    }
  }
  return values;
}

export function cycleConfigurationToCycleRequest(
  configuration: CycleConfiguration,
  schema: CycleEditorSchema,
  options: BuildCycleRequestOptions = {},
): CycleRequest {
  if (!("bar" in configuration.equipment)) {
    throw new Error("BAR_PROFILE_RESOLUTION_REQUIRED");
  }
  const values = cycleConfigurationToEditorValues(configuration, schema);
  const request = buildCycleRequest(schema, values, options);
  return {
    ...request,
    templateId: configuration.template.id,
    variantId: configuration.template.variantId,
    scheduleId: configuration.schedule.id,
    startDate: configuration.schedule.startDate,
    sessionOrder: configuration.schedule.sessionOrder,
    maxInputs: Object.fromEntries(Object.entries(configuration.maxes.values).map(
      ([movement, input]) => [movement, { type: configuration.maxes.mode, ...input }],
    )),
    globalTrainingMaxRatioBasisPoints:
      configuration.maxes.globalTrainingMaxRatioBasisPoints,
    options: {
      ...configuration.template.options,
      ...configuration.commonOptions,
    },
    unit: configuration.equipment.unit,
    barProfile: configuration.equipment.bar,
    includeDeload: configuration.commonOptions.deload.enabled,
    programTitle: configuration.output.title,
    showPlating: configuration.output.showPlating,
    ...(configuration.schedule.trainingDays === undefined
      ? {}
      : { trainingDays: configuration.schedule.trainingDays }),
    ...(configuration.maxes.ratiosByMovement === undefined
      ? {}
      : { trainingMaxRatioByMovement: configuration.maxes.ratiosByMovement }),
  };
}

export function migrateCycleRequestV1ToConfiguration(
  request: CycleRequest,
  catalog: CatalogMetadata,
): CycleConfiguration {
  return cycleRequestToConfiguration(request, catalog);
}

function cycleRequestToConfiguration(
  request: CycleRequest,
  catalog: CatalogMetadata,
): CycleConfiguration {
  const templateOptions: Record<string, unknown> = {};
  const commonOptions: Record<string, unknown> = {};
  for (const [name, option] of Object.entries(request.options ?? {})) {
    (commonOptionNames.has(name) ? commonOptions : templateOptions)[name] = option;
  }

  if (request.scheduleId === undefined) throw new Error("SCHEDULE_ID_REQUIRED");
  return {
    format: "hybrid-training-cycle",
    configurationVersion: 1,
    catalogVersion: catalog.catalogVersion,
    catalogHash: catalog.catalogHash,
    template: {
      id: request.templateId,
      variantId: request.variantId,
      options: templateOptions,
    },
    commonOptions: {
      warmUp: { enabled: false },
      joker: { enabled: false },
      deload: { enabled: false },
      ...commonOptions,
    },
    maxes: {
      mode: request.maxInputs[Object.keys(request.maxInputs)[0] ?? ""]?.type ?? "oneRepMax",
      globalTrainingMaxRatioBasisPoints: request.globalTrainingMaxRatioBasisPoints,
      values: Object.fromEntries(Object.entries(request.maxInputs).map(([movement, input]) => [
        movement,
        {
          weight: input.weight,
          ...(input.repetitions === undefined ? {} : { repetitions: input.repetitions }),
          ...(input.formula === undefined ? {} : { formula: input.formula }),
        },
      ])),
      ...(request.trainingMaxRatioByMovement === undefined
        ? {}
        : { ratiosByMovement: request.trainingMaxRatioByMovement }),
    },
    schedule: {
      id: request.scheduleId,
      startDate: request.startDate,
      sessionOrder: request.sessionOrder,
      ...(request.trainingDays === undefined ? {} : { trainingDays: request.trainingDays }),
    },
    equipment: {
      unit: request.unit,
      bar: request.barProfile,
    },
    output: {
      title: request.programTitle ?? "5/3/1",
      showPlating: request.showPlating ?? false,
    },
  } as CycleConfiguration;
}

function flattenOptions(
  values: Record<string, JsonValue>,
  options: Readonly<Record<string, unknown>>,
  prefix = "options",
): void {
  for (const [key, value] of Object.entries(options)) {
    const path = `${prefix}.${key}`;
    if (isRecord(value) && !isWeight(value)) flattenOptions(values, value, path);
    else values[path] = structuredClone(value) as JsonValue;
  }
}

function isWeight(value: unknown): value is Weight {
  return isRecord(value)
    && typeof value.centiUnits === "number"
    && (value.unit === "kg" || value.unit === "lb");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
