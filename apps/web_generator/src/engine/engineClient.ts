import type { ContractMetadata } from '../../../../contracts/v1/generated/contracts';

export type CatalogMovementLabels = Readonly<
  Record<string, Readonly<Record<string, string>>>
>;

export interface EngineBridge {
  initialize(catalogJson: string): string;
  engineInfo(): string;
  catalogIndex(requestJson: string): string;
  cycleEditorSchema(requestJson: string): string;
  configurationToCycleRequest(configurationJson: string): string;
  validateCycle(requestJson: string): string;
  generateCycle(requestJson: string): string;
  generateMacrocycle(requestJson: string): string;
}

declare global {
  interface Window {
    hybridTrainingEngine?: EngineBridge;
  }
}

export class EngineClient {
  private constructor(
    private readonly bridge: EngineBridge,
    private readonly metadata: ContractMetadata,
    private readonly movementLabels: CatalogMovementLabels,
  ) {}

  static async initialize(catalogUrl = '../catalog.bundle.json'): Promise<EngineClient> {
    const bridge = window.hybridTrainingEngine;
    if (!bridge) throw new Error('ENGINE_BRIDGE_UNAVAILABLE');
    const resolvedCatalogUrl = new URL(catalogUrl, window.location.href);
    if (resolvedCatalogUrl.origin !== window.location.origin) {
      throw new Error('EXTERNAL_CATALOG_URL_FORBIDDEN');
    }
    const response = await fetch(resolvedCatalogUrl, { credentials: 'same-origin' });
    if (!response.ok) throw new Error(`CATALOG_LOAD_FAILED:${response.status}`);
    const catalogJson = await response.text();
    const initialized = parseObject(bridge.initialize(catalogJson));
    const metadata = requireMetadata(initialized);
    return new EngineClient(
      bridge,
      metadata,
      extractCatalogMovementLabels(catalogJson),
    );
  }

  engineInfo<T>(): T {
    return this.parse<T>(this.bridge.engineInfo());
  }

  contractMetadata(): ContractMetadata {
    return { ...this.metadata };
  }

  catalogMovementLabels(): CatalogMovementLabels {
    return this.movementLabels;
  }

  catalogIndex<T>(request: object): T {
    return this.call<T>(this.bridge.catalogIndex.bind(this.bridge), request);
  }

  cycleEditorSchema<T>(request: object): T {
    return this.call<T>(this.bridge.cycleEditorSchema.bind(this.bridge), request);
  }

  configurationToCycleRequest<T>(configuration: object): T {
    const request = parseObject(
      this.bridge.configurationToCycleRequest(JSON.stringify(configuration)),
    );
    if (request.apiVersion !== 'v1' || request.schemaVersion !== 1) {
      throw new Error('ENGINE_CONTRACT_VERSION_UNSUPPORTED');
    }
    return request as T;
  }

  validateCycle<T>(request: object): T {
    return this.call<T>(this.bridge.validateCycle.bind(this.bridge), request);
  }

  generateCycle<T>(request: object): T {
    return this.call<T>(this.bridge.generateCycle.bind(this.bridge), request);
  }

  generateMacrocycle<T>(request: object): T {
    return this.call<T>(this.bridge.generateMacrocycle.bind(this.bridge), request);
  }

  private call<T>(operation: (json: string) => string, request: object): T {
    return this.parse<T>(operation(JSON.stringify(request)));
  }

  private parse<T>(json: string): T {
    const value = parseObject(json);
    const metadata = requireMetadata(value);
    if (
      metadata.engineVersion !== this.metadata.engineVersion ||
      metadata.catalogVersion !== this.metadata.catalogVersion ||
      metadata.catalogHash !== this.metadata.catalogHash
    ) throw new Error('ENGINE_RESPONSE_VERSION_MISMATCH');
    return value as T;
  }
}

function parseObject(json: string): Record<string, unknown> {
  const value: unknown = JSON.parse(json);
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('ENGINE_RESPONSE_OBJECT_REQUIRED');
  }
  return value as Record<string, unknown>;
}

function requireMetadata(value: Record<string, unknown>): ContractMetadata {
  if (
    value.apiVersion !== 'v1' ||
    value.schemaVersion !== 1 ||
    typeof value.engineVersion !== 'string' ||
    typeof value.catalogVersion !== 'number' ||
    typeof value.catalogHash !== 'string'
  ) throw new Error('ENGINE_CONTRACT_VERSION_UNSUPPORTED');
  return value as unknown as ContractMetadata;
}

function extractCatalogMovementLabels(
  catalogJson: string,
): CatalogMovementLabels {
  const catalog = parseObject(catalogJson);
  const documents = Array.isArray(catalog.documents) ? catalog.documents : [];
  const labels: Record<string, Readonly<Record<string, string>>> = {};
  for (const candidate of documents) {
    if (!isRecord(candidate) || !isRecord(candidate.content)) continue;
    const content = candidate.content;
    const collection = content.kind === 'movements'
      ? content.movements
      : content.kind === 'exercises'
      ? content.exercises
      : undefined;
    if (!Array.isArray(collection)) continue;
    for (const item of collection) {
      if (!isRecord(item) || typeof item.id !== 'string' || !isRecord(item.labels)) {
        continue;
      }
      const localized = Object.fromEntries(
        Object.entries(item.labels).filter(
          (entry): entry is [string, string] => typeof entry[1] === 'string',
        ),
      );
      if (Object.keys(localized).length > 0) {
        labels[item.id] = Object.freeze(localized);
      }
    }
  }
  return Object.freeze(labels);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
