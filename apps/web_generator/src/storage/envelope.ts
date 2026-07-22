export interface EnvelopeLike<T = unknown> {
  readonly apiVersion: string;
  readonly engineVersion: string;
  readonly catalogVersion: string | number;
  readonly catalogHash: string;
  readonly schemaVersion: string | number;
  readonly payload: T;
}

const metadataKeys = [
  "apiVersion",
  "engineVersion",
  "catalogVersion",
  "catalogHash",
  "schemaVersion",
] as const;

export function isVersionedEnvelope(value: unknown): value is EnvelopeLike {
  if (!isRecord(value) || !("payload" in value)) return false;
  return metadataKeys.every((key) => {
    const field = value[key];
    return typeof field === "string" || typeof field === "number";
  });
}

export function exportEnvelope(envelope: EnvelopeLike): string {
  assertEnvelope(envelope);
  return JSON.stringify(envelope);
}

export function importEnvelope<T = unknown>(json: string): EnvelopeLike<T> {
  const value: unknown = JSON.parse(json);
  assertEnvelope(value);
  return clone(value as EnvelopeLike<T>);
}

export function clone<T>(value: T): T {
  return structuredClone(value);
}

function assertEnvelope(value: unknown): asserts value is EnvelopeLike {
  if (!isVersionedEnvelope(value)) {
    throw new TypeError("Invalid versioned envelope");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
