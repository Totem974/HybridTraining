import type { CycleConfiguration } from "../../../../../contracts/v1/generated/contracts";

export const CYCLE_SHARE_PARAMETER = "cycle";
export const MAX_SHARED_CYCLE_BYTES = 128 * 1024;

/**
 * Serializes a Cycle configuration in a stable form suitable for URLs.
 *
 * Object keys are sorted recursively; array order remains significant.
 */
export function canonicalCycleConfigurationJson(
  configuration: CycleConfiguration,
): string {
  assertSupportedConfiguration(configuration);
  return canonicalJson(configuration);
}

export function encodeCycleConfiguration(
  configuration: CycleConfiguration,
): string {
  const bytes = new TextEncoder().encode(
    canonicalCycleConfigurationJson(configuration),
  );
  if (bytes.byteLength > MAX_SHARED_CYCLE_BYTES) {
    throw new CycleShareError("CYCLE_SHARE_TOO_LARGE");
  }
  return bytesToBase64(bytes)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}

export function decodeCycleConfiguration(
  encoded: string,
): CycleConfiguration {
  if (
    encoded.length === 0
    || !/^[A-Za-z0-9_-]+$/u.test(encoded)
    || encoded.length % 4 === 1
    || encoded.length > maximumEncodedLength()
  ) {
    throw new CycleShareError("INVALID_CYCLE_SHARE");
  }

  let bytes: Uint8Array;
  try {
    const base64 = encoded.replaceAll("-", "+").replaceAll("_", "/")
      .padEnd(Math.ceil(encoded.length / 4) * 4, "=");
    bytes = base64ToBytes(base64);
  } catch {
    throw new CycleShareError("INVALID_CYCLE_SHARE");
  }
  if (bytes.byteLength > MAX_SHARED_CYCLE_BYTES) {
    throw new CycleShareError("CYCLE_SHARE_TOO_LARGE");
  }

  let parsed: unknown;
  try {
    const json = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    parsed = JSON.parse(json) as unknown;
  } catch {
    throw new CycleShareError("INVALID_CYCLE_SHARE");
  }
  assertSupportedConfiguration(parsed);
  return parsed;
}

export function createCycleShareUrl(
  configuration: CycleConfiguration,
  baseUrl: string | URL = globalThis.location.href,
): URL {
  const url = new URL(baseUrl);
  url.searchParams.set(
    CYCLE_SHARE_PARAMETER,
    encodeCycleConfiguration(configuration),
  );
  return url;
}

export function readCycleConfigurationFromUrl(
  input: string | URL = globalThis.location.href,
): CycleConfiguration | null {
  const encoded = new URL(input).searchParams.get(CYCLE_SHARE_PARAMETER);
  return encoded === null ? null : decodeCycleConfiguration(encoded);
}

export class CycleShareError extends Error {
  constructor(
    public readonly code:
      | "INVALID_CYCLE_SHARE"
      | "CYCLE_SHARE_TOO_LARGE"
      | "UNSUPPORTED_CYCLE_CONFIGURATION",
  ) {
    super(code);
    this.name = "CycleShareError";
  }
}

export function isSupportedCycleConfiguration(
  value: unknown,
): value is CycleConfiguration {
  try {
    assertSupportedConfiguration(value);
    return true;
  } catch (error) {
    if (error instanceof CycleShareError) return false;
    throw error;
  }
}

function assertSupportedConfiguration(
  value: unknown,
): asserts value is CycleConfiguration {
  const expectedKeys = new Set([
    "format",
    "configurationVersion",
    "catalogVersion",
    "catalogHash",
    "template",
    "commonOptions",
    "maxes",
    "schedule",
    "equipment",
    "output",
  ]);
  if (
    !isRecord(value)
    || value.format !== "hybrid-training-cycle"
    || value.configurationVersion !== 1
    || typeof value.catalogVersion !== "number"
    || typeof value.catalogHash !== "string"
    || !isRecord(value.template)
    || !isRecord(value.commonOptions)
    || !isRecord(value.maxes)
    || !isRecord(value.schedule)
    || !isRecord(value.equipment)
    || !isRecord(value.output)
    || Object.keys(value).some((key) => !expectedKeys.has(key))
  ) {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }
  assertSupportedMaxes(value.maxes);
}

function assertSupportedMaxes(maxes: Record<string, unknown>): void {
  const expectedKeys = new Set([
    "mode",
    "globalTrainingMaxRatioBasisPoints",
    "values",
    "ratiosByMovement",
  ]);
  const mode = maxes.mode;
  if (
    (mode !== "oneRepMax"
      && mode !== "onePlusSet"
      && mode !== "repMax"
      && mode !== "directTrainingMax")
    || !isBasisPoints(maxes.globalTrainingMaxRatioBasisPoints)
    || !isRecord(maxes.values)
    || Object.keys(maxes.values).length === 0
    || Object.keys(maxes).some((key) => !expectedKeys.has(key))
  ) {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }

  for (const value of Object.values(maxes.values)) {
    assertSupportedMaxValue(value, mode);
  }
  if (
    maxes.ratiosByMovement !== undefined
    && (
      !isRecord(maxes.ratiosByMovement)
      || Object.values(maxes.ratiosByMovement).some(
        (ratio) => !isBasisPoints(ratio),
      )
    )
  ) {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }
}

function assertSupportedMaxValue(
  value: unknown,
  mode: "oneRepMax" | "onePlusSet" | "repMax" | "directTrainingMax",
): void {
  const allowedKeys = mode === "repMax"
    ? new Set(["weight", "repetitions", "formula"])
    : new Set(["weight"]);
  if (
    !isRecord(value)
    || !isWeight(value.weight)
    || Object.keys(value).some((key) => !allowedKeys.has(key))
    || (
      mode === "repMax"
      && (
        !Number.isInteger(value.repetitions)
        || (value.repetitions as number) < 1
        || (
          value.formula !== undefined
          && (typeof value.formula !== "string" || value.formula.length === 0)
        )
      )
    )
  ) {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }
}

function isWeight(value: unknown): boolean {
  return isRecord(value)
    && Object.keys(value).length === 2
    && Number.isInteger(value.centiUnits)
    && (value.centiUnits as number) >= 0
    && (value.unit === "kg" || value.unit === "lb");
}

function isBasisPoints(value: unknown): boolean {
  return Number.isInteger(value) && (value as number) >= 0 && (value as number) <= 20000;
}

function canonicalJson(value: unknown, ancestors = new Set<object>()): string {
  if (value === null) return "null";
  if (typeof value === "string" || typeof value === "boolean") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
    }
    return JSON.stringify(value);
  }
  if (typeof value !== "object") {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }
  if (ancestors.has(value)) {
    throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
  }

  ancestors.add(value);
  try {
    if (Array.isArray(value)) {
      return `[${value.map((item) => canonicalJson(item, ancestors)).join(",")}]`;
    }
    if (!isRecord(value)) {
      throw new CycleShareError("UNSUPPORTED_CYCLE_CONFIGURATION");
    }
    const entries = Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonicalJson(value[key], ancestors)}`
    );
    return `{${entries.join(",")}}`;
  } finally {
    ancestors.delete(value);
  }
}

function maximumEncodedLength(): number {
  return Math.ceil(MAX_SHARED_CYCLE_BYTES / 3) * 4;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
