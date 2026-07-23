import { describe, expect, it } from "vitest";

import type { CycleConfiguration } from "../../../src/cycle/configuration";
import {
  canonicalCycleConfigurationJson,
  createCycleShareUrl,
  CycleShareError,
  decodeCycleConfiguration,
  encodeCycleConfiguration,
  MAX_SHARED_CYCLE_BYTES,
  readCycleConfigurationFromUrl,
} from "../../../src/cycle/configuration/share";

describe("Cycle configuration sharing", () => {
  it("round-trips Unicode locally through the cycle URL parameter", () => {
    const configuration = makeConfiguration({
      output: { title: "Cycle été — 力 💪", showPlating: true },
    });

    const url = createCycleShareUrl(
      configuration,
      "https://local.invalid/cycle/?language=fr#program",
    );

    expect(url.searchParams.get("language")).toBe("fr");
    expect(url.hash).toBe("#program");
    expect(readCycleConfigurationFromUrl(url)).toEqual(configuration);
    expect(url.searchParams.get("cycle")).toMatch(/^[A-Za-z0-9_-]+$/u);
  });

  it("sorts object keys recursively without changing array order", () => {
    const first = makeConfiguration({
      template: {
        id: "bbb",
        variantId: "original",
        options: { zeta: { b: 2, a: 1 }, alpha: true },
      },
    });
    const second = makeConfiguration({
      template: {
        options: { alpha: true, zeta: { a: 1, b: 2 } },
        variantId: "original",
        id: "bbb",
      },
    });

    expect(canonicalCycleConfigurationJson(first))
      .toBe(canonicalCycleConfigurationJson(second));
    expect(encodeCycleConfiguration(first)).toBe(encodeCycleConfiguration(second));
    expect(decodeCycleConfiguration(encodeCycleConfiguration(first)).schedule.sessionOrder)
      .toEqual(["overhead_press", "deadlift"]);
  });

  it("round-trips a weight-only onePlusSet configuration", () => {
    const configuration = makeConfiguration({
      maxes: {
        mode: "onePlusSet",
        globalTrainingMaxRatioBasisPoints: 5000,
        values: {
          squat: { weight: { centiUnits: 9500, unit: "kg" } },
        },
      },
    });

    expect(decodeCycleConfiguration(encodeCycleConfiguration(configuration)))
      .toEqual(configuration);
  });

  it.each([
    "",
    "not+base64",
    "A",
    "eyJmb3JtYXQiOiJub3QtYS1jeWNsZSJ9",
  ])("rejects invalid input: %s", (encoded) => {
    expect(() => decodeCycleConfiguration(encoded)).toThrow(CycleShareError);
  });

  it("rejects unsupported configuration versions", () => {
    const unsupported = {
      ...makeConfiguration(),
      configurationVersion: 2,
    };
    const encoded = toBase64Url(JSON.stringify(unsupported));

    expect(() => decodeCycleConfiguration(encoded)).toThrowError(
      expect.objectContaining({ code: "UNSUPPORTED_CYCLE_CONFIGURATION" }),
    );
  });

  it("rejects truncated documents and unknown top-level fields", () => {
    const truncated = {
      format: "hybrid-training-cycle",
      configurationVersion: 1,
      catalogVersion: 7,
      catalogHash: "sha256:test",
    };
    expect(() => decodeCycleConfiguration(toBase64Url(JSON.stringify(truncated))))
      .toThrowError(expect.objectContaining({
        code: "UNSUPPORTED_CYCLE_CONFIGURATION",
      }));

    const extended = { ...makeConfiguration(), unexpected: true };
    expect(() => decodeCycleConfiguration(toBase64Url(JSON.stringify(extended))))
      .toThrowError(expect.objectContaining({
        code: "UNSUPPORTED_CYCLE_CONFIGURATION",
      }));
  });

  it("rejects unknown onePlusSet value fields during import", () => {
    const configuration = makeConfiguration({
      maxes: {
        mode: "onePlusSet",
        globalTrainingMaxRatioBasisPoints: 9000,
        values: {
          squat: { weight: { centiUnits: 9500, unit: "kg" } },
        },
      },
    });
    const unsupported = {
      ...configuration,
      maxes: {
        ...configuration.maxes,
        values: {
          squat: {
            weight: { centiUnits: 9500, unit: "kg" },
            repetitions: 1,
          },
        },
      },
    };

    expect(() =>
      decodeCycleConfiguration(toBase64Url(JSON.stringify(unsupported)))
    ).toThrowError(expect.objectContaining({
      code: "UNSUPPORTED_CYCLE_CONFIGURATION",
    }));
  });

  it("rejects encoded and decoded payloads over the size limit", () => {
    const oversizedConfiguration = makeConfiguration({
      output: {
        title: "a".repeat(MAX_SHARED_CYCLE_BYTES),
        showPlating: false,
      },
    });
    expect(() => encodeCycleConfiguration(oversizedConfiguration)).toThrowError(
      expect.objectContaining({ code: "CYCLE_SHARE_TOO_LARGE" }),
    );

    const oversizedEncoded = "A".repeat(
      Math.ceil(MAX_SHARED_CYCLE_BYTES / 3) * 4 + 1,
    );
    expect(() => decodeCycleConfiguration(oversizedEncoded)).toThrow(CycleShareError);
  });

  it("returns null when the URL has no shared Cycle configuration", () => {
    expect(readCycleConfigurationFromUrl("https://local.invalid/cycle/?language=en"))
      .toBeNull();
  });
});

function makeConfiguration(
  overrides: Partial<CycleConfiguration> = {},
): CycleConfiguration {
  return {
    format: "hybrid-training-cycle",
    configurationVersion: 1,
    catalogVersion: 7,
    catalogHash: "sha256:test",
    template: {
      id: "bbb",
      variantId: "original",
      options: { ratio: 5000 },
    },
    commonOptions: {
      warmUp: { enabled: true, type: "original" },
      joker: { enabled: false },
      deload: { enabled: true, type: "deload1" },
    },
    maxes: {
      mode: "oneRepMax",
      globalTrainingMaxRatioBasisPoints: 9000,
      values: {
        squat: { weight: { centiUnits: 12000, unit: "kg" } },
      },
    },
    schedule: {
      id: "four_days",
      startDate: "2026-07-27T00:00:00.000Z",
      sessionOrder: ["overhead_press", "deadlift"],
    },
    equipment: {
      unit: "kg",
      barProfileId: "default_kg",
    },
    output: {
      title: "5/3/1",
      showPlating: false,
    },
    ...overrides,
  } as CycleConfiguration;
}

function toBase64Url(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replace(/=+$/u, "");
}
