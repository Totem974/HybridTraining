// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from "vitest";

import { EngineClient, type EngineBridge } from "../../../src/engine";

const metadata = {
  apiVersion: "v1",
  schemaVersion: 1,
  engineVersion: "test-engine",
  catalogVersion: 2,
  catalogHash: "hash",
} as const;

afterEach(() => {
  delete window.hybridTrainingEngine;
  vi.unstubAllGlobals();
});

describe("EngineClient", () => {
  it("rejects external catalog URLs before fetching", async () => {
    window.hybridTrainingEngine = bridge();
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    await expect(EngineClient.initialize("https://example.com/catalog.json"))
      .rejects.toThrow("EXTERNAL_CATALOG_URL_FORBIDDEN");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects response metadata that differs from initialization", async () => {
    const local = bridge();
    local.catalogIndex = () => JSON.stringify({ ...metadata, catalogHash: "other", templates: [] });
    window.hybridTrainingEngine = local;
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: true, text: async () => "{}" }));
    const client = await EngineClient.initialize();
    expect(() => client.catalogIndex({ apiVersion: "v1", schemaVersion: 1 }))
      .toThrow("ENGINE_RESPONSE_VERSION_MISMATCH");
  });

  it("reuses the loaded catalog to expose movement and exercise labels", async () => {
    const catalogJson = JSON.stringify({
      documents: [
        {
          content: {
            kind: "movements",
            movements: [{
              id: "overhead_press",
              labels: { en: "Overhead press", fr: "Développé militaire" },
            }],
          },
        },
        {
          content: {
            kind: "exercises",
            exercises: [{
              id: "dumbbell_row",
              labels: { en: "Dumbbell row", fr: "Rowing haltère" },
            }],
          },
        },
      ],
    });
    const local = bridge();
    const initialize = vi.fn(() =>
      JSON.stringify({ ...metadata, initialized: true })
    );
    local.initialize = initialize;
    window.hybridTrainingEngine = local;
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      text: async () => catalogJson,
    });
    vi.stubGlobal("fetch", fetchMock);

    const client = await EngineClient.initialize();

    expect(client.catalogMovementLabels()).toEqual({
      overhead_press: {
        en: "Overhead press",
        fr: "Développé militaire",
      },
      dumbbell_row: {
        en: "Dumbbell row",
        fr: "Rowing haltère",
      },
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(initialize).toHaveBeenCalledWith(catalogJson);
  });
});

function bridge(): EngineBridge {
  const response = JSON.stringify(metadata);
  return {
    initialize: () => JSON.stringify({ ...metadata, initialized: true }),
    engineInfo: () => response,
    catalogIndex: () => JSON.stringify({ ...metadata, templates: [] }),
    cycleEditorSchema: () => response,
    configurationToCycleRequest: () => response,
    validateCycle: () => response,
    generateCycle: () => response,
    generateMacrocycle: () => response,
  };
}
