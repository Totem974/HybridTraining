import {
  clone,
  exportEnvelope,
  importEnvelope,
  type EnvelopeLike,
} from "./envelope";

export type LocalArtifactKind = "configuration" | "program";

export interface LocalArtifact<T = unknown> extends EnvelopeLike<T> {
  readonly artifactKind: LocalArtifactKind;
}

export interface EngineValidationReport {
  readonly valid: boolean;
  readonly errors?: readonly unknown[];
}

export type EngineImportValidator<T> = (
  artifact: Readonly<LocalArtifact<T>>,
) => EngineValidationReport | Promise<EngineValidationReport>;

/** Serializes a configuration without transforming its engine-owned payload. */
export function exportConfiguration<T>(artifact: LocalArtifact<T>): string {
  requireKind(artifact, "configuration");
  return exportEnvelope(artifact);
}

/** Serializes a generated program without transforming its engine-owned payload. */
export function exportProgram<T>(artifact: LocalArtifact<T>): string {
  requireKind(artifact, "program");
  return exportEnvelope(artifact);
}

/**
 * Imports a local artifact only after the caller's engine adapter accepts it.
 * The storage layer deliberately has no business validation of its own.
 */
export async function importValidatedArtifact<T>(
  json: string,
  expectedKind: LocalArtifactKind,
  validateWithEngine: EngineImportValidator<T>,
): Promise<LocalArtifact<T>> {
  const envelope = importEnvelope<T>(json);
  requireKind(envelope, expectedKind);
  const candidate = clone(envelope as LocalArtifact<T>);
  const report = await validateWithEngine(candidate);
  if (!report.valid || (report.errors?.length ?? 0) > 0) {
    throw new TypeError("Artifact rejected by the local engine");
  }
  return clone(candidate);
}

function requireKind<T>(
  value: EnvelopeLike<T>,
  expected: LocalArtifactKind,
): asserts value is LocalArtifact<T> {
  if (
    !("artifactKind" in value) ||
    (value as { artifactKind?: unknown }).artifactKind !== expected
  ) {
    throw new TypeError(`Expected a ${expected} artifact`);
  }
}
