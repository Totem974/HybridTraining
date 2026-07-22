import type { ContractMetadata } from "../../../../../contracts/v1/generated/contracts";
import type { JsonValue } from "../form/types";
import type {
  EnvelopeLike,
  VersionedEnvelopeRepository,
} from "../../storage";

export const currentDraftId = "cycle-current";
export const cycleDraftVersion = 1;

export interface CycleDraftPayload {
  readonly draftVersion: 1;
  readonly templateId: string;
  readonly variantId: string;
  readonly scheduleId?: string;
  readonly values: Readonly<Record<string, JsonValue>>;
}

export function draftEnvelope(
  metadata: ContractMetadata,
  payload: CycleDraftPayload,
): EnvelopeLike<CycleDraftPayload> {
  return { ...metadata, payload: structuredClone(payload) };
}

export async function restoreCompatibleDraft(
  repository: VersionedEnvelopeRepository<CycleDraftPayload>,
  metadata: ContractMetadata,
  allowedSelections: ReadonlyMap<string, ReadonlySet<string>>,
): Promise<CycleDraftPayload | undefined> {
  const records = await repository.list();
  let restored: CycleDraftPayload | undefined;
  for (const record of records) {
    const payload = record.envelope.payload;
    const compatible = metadataMatches(record.envelope, metadata) &&
      isDraftPayload(payload) &&
      allowedSelections.get(payload.templateId)?.has(payload.variantId) === true;
    if (!compatible) {
      await repository.delete(record.id);
      continue;
    }
    if (record.id === currentDraftId) restored = structuredClone(payload);
  }
  return restored;
}

export function cycleDraft(
  values: Readonly<Record<string, JsonValue>>,
): CycleDraftPayload {
  const templateId = typeof values.templateId === "string" ? values.templateId : "";
  const variantId = typeof values.variantId === "string" ? values.variantId : "";
  const scheduleId = typeof values.scheduleId === "string" ? values.scheduleId : undefined;
  return {
    draftVersion: cycleDraftVersion,
    templateId,
    variantId,
    ...(scheduleId ? { scheduleId } : {}),
    values: structuredClone(values),
  };
}

function metadataMatches(envelope: EnvelopeLike, metadata: ContractMetadata): boolean {
  return envelope.apiVersion === metadata.apiVersion &&
    envelope.schemaVersion === metadata.schemaVersion &&
    envelope.engineVersion === metadata.engineVersion &&
    envelope.catalogVersion === metadata.catalogVersion &&
    envelope.catalogHash === metadata.catalogHash;
}

function isDraftPayload(value: unknown): value is CycleDraftPayload {
  if (!isRecord(value) || value.draftVersion !== cycleDraftVersion) return false;
  return typeof value.templateId === "string" &&
    typeof value.variantId === "string" &&
    isRecord(value.values);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
