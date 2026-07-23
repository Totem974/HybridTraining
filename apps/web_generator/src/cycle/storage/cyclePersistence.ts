import type {
  ContractMetadata,
  CycleConfiguration,
} from "../../../../../contracts/v1/generated/contracts";
import type { JsonValue } from "../form/types";
import type { EnvelopeLike, VersionedEnvelopeRepository } from "../../storage";

export const currentDraftId = "cycle-current";
export const cycleDraftVersion = 2;

export interface CanonicalCycleDraftPayload {
  readonly draftVersion: 2;
  readonly configuration: CycleConfiguration;
  readonly editorValues: Readonly<Record<string, JsonValue>>;
}

/** @deprecated Temporary adapter removed when main writes CycleConfiguration. */
export interface EditorValuesCycleDraftPayload {
  readonly draftVersion: 2;
  readonly editorValues: Readonly<Record<string, JsonValue>>;
}

export type CycleDraftPayload =
  | CanonicalCycleDraftPayload
  | EditorValuesCycleDraftPayload;

export interface LegacyCycleDraftPayloadV1 {
  readonly draftVersion: 1;
  readonly templateId: string;
  readonly variantId: string;
  readonly scheduleId?: string;
  readonly values: Readonly<Record<string, JsonValue>>;
}

export interface RestoredCycleDraft {
  readonly templateId: string;
  readonly variantId: string;
  readonly scheduleId?: string;
  readonly values: Readonly<Record<string, JsonValue>>;
  readonly configuration?: CycleConfiguration;
}

export type LegacyDraftMigration = (
  payload: LegacyCycleDraftPayloadV1,
) => CanonicalCycleDraftPayload | undefined;

export function draftEnvelope(
  metadata: ContractMetadata,
  payload: CycleDraftPayload,
): EnvelopeLike<CycleDraftPayload> {
  return { ...metadata, payload: structuredClone(payload) };
}

/**
 * Restores only a compatible current draft. Unknown, stale and rejected legacy
 * records remain in IndexedDB so a future migration can recover them.
 */
export async function restoreCompatibleDraft<T>(
  repository: VersionedEnvelopeRepository<T>,
  metadata: ContractMetadata,
  allowedSelections: ReadonlyMap<string, ReadonlySet<string>>,
  migrateLegacy?: LegacyDraftMigration,
): Promise<RestoredCycleDraft | undefined> {
  const current = (await repository.list()).find((record) => record.id === currentDraftId);
  if (!current || !metadataMatches(current.envelope, metadata)) return undefined;

  const payload = current.envelope.payload;
  const migrated = isLegacyDraftPayload(payload) ? migrateLegacy?.(payload) : undefined;
  const decoded = decodeDraft(migrated ?? payload);
  if (!decoded ||
    allowedSelections.get(decoded.templateId)?.has(decoded.variantId) !== true) {
    return undefined;
  }

  if (migrated) {
    await repository.save(
      currentDraftId,
      draftEnvelope(metadata, migrated) as EnvelopeLike<T>,
      new Date(current.updatedAt),
    );
  }
  return structuredClone(decoded);
}

export function cycleDraft(
  configuration: CycleConfiguration,
  editorValues: Readonly<Record<string, JsonValue>>,
): CanonicalCycleDraftPayload;
/** @deprecated Pass a canonical CycleConfiguration and editor values. */
export function cycleDraft(
  editorValues: Readonly<Record<string, JsonValue>>,
): EditorValuesCycleDraftPayload;
export function cycleDraft(
  configurationOrValues: CycleConfiguration | Readonly<Record<string, JsonValue>>,
  editorValues?: Readonly<Record<string, JsonValue>>,
): CycleDraftPayload {
  if (isCycleConfiguration(configurationOrValues)) {
    if (!editorValues) throw new TypeError("editorValues are required with CycleConfiguration");
    return {
      draftVersion: cycleDraftVersion,
      configuration: structuredClone(configurationOrValues),
      editorValues: structuredClone(editorValues),
    };
  }
  return {
    draftVersion: cycleDraftVersion,
    editorValues: structuredClone(configurationOrValues),
  };
}

function decodeDraft(value: unknown): RestoredCycleDraft | undefined {
  if (!isCycleDraftPayload(value)) return undefined;
  const values = value.editorValues;
  const configuration = "configuration" in value ? value.configuration : undefined;
  const templateId = configuration?.template.id ?? stringValue(values.templateId);
  const variantId = configuration?.template.variantId ?? stringValue(values.variantId);
  const scheduleId = configuration?.schedule.id ?? stringValue(values.scheduleId);
  if (!templateId || !variantId) return undefined;
  return {
    templateId,
    variantId,
    ...(scheduleId ? { scheduleId } : {}),
    values: structuredClone(values),
    ...(configuration ? { configuration: structuredClone(configuration) } : {}),
  };
}

function metadataMatches(envelope: EnvelopeLike, metadata: ContractMetadata): boolean {
  return envelope.apiVersion === metadata.apiVersion &&
    envelope.schemaVersion === metadata.schemaVersion &&
    envelope.engineVersion === metadata.engineVersion &&
    envelope.catalogVersion === metadata.catalogVersion &&
    envelope.catalogHash === metadata.catalogHash;
}

function isCycleDraftPayload(value: unknown): value is CycleDraftPayload {
  if (!isRecord(value) || value.draftVersion !== cycleDraftVersion ||
    !isRecord(value.editorValues)) return false;
  return value.configuration === undefined || isCycleConfiguration(value.configuration);
}

function isLegacyDraftPayload(value: unknown): value is LegacyCycleDraftPayloadV1 {
  return isRecord(value) && value.draftVersion === 1 &&
    typeof value.templateId === "string" &&
    typeof value.variantId === "string" &&
    isRecord(value.values);
}

function isCycleConfiguration(value: unknown): value is CycleConfiguration {
  return isRecord(value) && value.format === "hybrid-training-cycle" &&
    value.configurationVersion === 1 && isRecord(value.template) &&
    typeof value.template.id === "string" &&
    typeof value.template.variantId === "string" && isRecord(value.schedule) &&
    typeof value.schedule.id === "string";
}

function stringValue(value: JsonValue | undefined): string | undefined {
  return typeof value === "string" && value !== "" ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
