import type {
  ContractMetadata,
  CycleConfiguration,
} from "../../../../../contracts/v1/generated/contracts";
import type { JsonValue } from "../form/types";
import type { EnvelopeLike, VersionedEnvelopeRepository } from "../../storage";
import { isSupportedCycleConfiguration } from "../configuration/share";

export const currentDraftId = "cycle-current";
export const cycleDraftVersion = 2;

export interface CanonicalCycleDraftPayload {
  readonly draftVersion: 2;
  readonly configuration: CycleConfiguration;
}
export type CycleDraftPayload = CanonicalCycleDraftPayload;

export interface LegacyCycleDraftPayloadV1 {
  readonly draftVersion: 1;
  readonly templateId: string;
  readonly variantId: string;
  readonly scheduleId?: string;
  readonly values: Readonly<Record<string, JsonValue>>;
}

export interface RestoredCycleDraft {
  readonly configuration: CycleConfiguration;
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
    allowedSelections.get(decoded.configuration.template.id)?.has(
      decoded.configuration.template.variantId,
    ) !== true) {
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
): CanonicalCycleDraftPayload {
  return {
    draftVersion: cycleDraftVersion,
    configuration: structuredClone(configuration),
  };
}

function decodeDraft(value: unknown): RestoredCycleDraft | undefined {
  if (!isCycleDraftPayload(value)) return undefined;
  return { configuration: structuredClone(value.configuration) };
}

function metadataMatches(envelope: EnvelopeLike, metadata: ContractMetadata): boolean {
  return envelope.apiVersion === metadata.apiVersion &&
    envelope.schemaVersion === metadata.schemaVersion &&
    envelope.engineVersion === metadata.engineVersion &&
    envelope.catalogVersion === metadata.catalogVersion &&
    envelope.catalogHash === metadata.catalogHash;
}

function isCycleDraftPayload(value: unknown): value is CycleDraftPayload {
  return isRecord(value) && value.draftVersion === cycleDraftVersion &&
    isSupportedCycleConfiguration(value.configuration);
}

function isLegacyDraftPayload(value: unknown): value is LegacyCycleDraftPayloadV1 {
  return isRecord(value) && value.draftVersion === 1 &&
    typeof value.templateId === "string" &&
    typeof value.variantId === "string" &&
    isRecord(value.values);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
