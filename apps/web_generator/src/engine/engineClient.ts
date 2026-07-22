export interface EngineBridge {
  initialize(catalogJson: string): string;
  engineInfo(): string;
  catalogIndex(requestJson: string): string;
  cycleEditorSchema(requestJson: string): string;
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
  private constructor(private readonly bridge: EngineBridge) {}

  static async initialize(catalogUrl = '../catalog.bundle.json'): Promise<EngineClient> {
    const bridge = window.hybridTrainingEngine;
    if (!bridge) throw new Error('ENGINE_BRIDGE_UNAVAILABLE');
    const resolvedCatalogUrl = new URL(catalogUrl, window.location.href);
    if (resolvedCatalogUrl.origin !== window.location.origin) {
      throw new Error('EXTERNAL_CATALOG_URL_FORBIDDEN');
    }
    const response = await fetch(resolvedCatalogUrl, { credentials: 'same-origin' });
    if (!response.ok) throw new Error(`CATALOG_LOAD_FAILED:${response.status}`);
    bridge.initialize(await response.text());
    return new EngineClient(bridge);
  }

  engineInfo<T>(): T {
    return this.parse<T>(this.bridge.engineInfo());
  }

  catalogIndex<T>(request: object): T {
    return this.call<T>(this.bridge.catalogIndex.bind(this.bridge), request);
  }

  cycleEditorSchema<T>(request: object): T {
    return this.call<T>(this.bridge.cycleEditorSchema.bind(this.bridge), request);
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
    const value: unknown = JSON.parse(json);
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('ENGINE_RESPONSE_OBJECT_REQUIRED');
    }
    return value as T;
  }
}
