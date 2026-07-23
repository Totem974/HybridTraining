import { IDBFactory } from "fake-indexeddb";
import { describe, expect, it } from "vitest";
import type { CycleConfiguration } from "../../../../../contracts/v1/generated/contracts";

import {
  currentDraftId,
  cycleDraft,
  cycleDraftVersion,
  draftEnvelope,
  restoreCompatibleDraft,
  type CycleDraftPayload,
} from "../../../src/cycle/storage/cyclePersistence";
import {
  IndexedDbWorkspaceStorage,
  WorkspaceDraftRepository,
} from "../../../src/storage";

const metadata = {
  apiVersion: "v1",
  schemaVersion: 1,
  engineVersion: "engine",
  catalogVersion: 2,
  catalogHash: "catalog",
} as const;

function configuration(templateId = "template", variantId = "variant"): CycleConfiguration {
  return {
    format: "hybrid-training-cycle",
    configurationVersion: 1,
    catalogVersion: 2,
    catalogHash: "catalog",
    template: { id: templateId, variantId, options: {} },
    commonOptions: {
      warmUp: { enabled: false },
      joker: { enabled: false },
      deload: { enabled: false },
    },
    maxes: {
      mode: "oneRepMax",
      globalTrainingMaxRatioBasisPoints: 8500,
      values: {
        squat: { weight: { centiUnits: 10000, unit: "kg" } },
      },
    },
    schedule: {
      id: "schedule",
      startDate: "2026-07-23T00:00:00.000Z",
      sessionOrder: ["squat"],
    },
    equipment: { unit: "kg", barProfileId: "default-kg" },
    output: { title: "Cycle", showPlating: true },
  };
}

describe("Cycle draft persistence", () => {
  it("round-trips a compatible v2 configuration and retains obsolete records", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const payload = cycleDraft(configuration());
    await repository.save(currentDraftId, draftEnvelope(metadata, payload));
    await repository.save("obsolete", {
      ...draftEnvelope(metadata, payload),
      engineVersion: "old-engine",
    });

    const restored = await restoreCompatibleDraft(
      repository,
      metadata,
      new Map([["template", new Set(["variant"])]]),
    );
    expect(restored).toEqual({ configuration: configuration() });
    expect((await repository.list()).map((record) => record.id).sort()).toEqual([
      currentDraftId,
      "obsolete",
    ]);
    storage.close();
  });

  it("round-trips a onePlusSet draft without adding rep-max fields", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const onePlusConfiguration: CycleConfiguration = {
      ...configuration(),
      maxes: {
        mode: "onePlusSet",
        globalTrainingMaxRatioBasisPoints: 5000,
        values: {
          squat: { weight: { centiUnits: 9500, unit: "kg" } },
        },
      },
    };
    await repository.save(
      currentDraftId,
      draftEnvelope(metadata, cycleDraft(onePlusConfiguration)),
    );

    const restored = await restoreCompatibleDraft(
      repository,
      metadata,
      new Map([["template", new Set(["variant"])]]),
    );
    expect(restored?.configuration).toEqual(onePlusConfiguration);
    storage.close();
  });

  it("round-trips movement-scoped GVT ratios in a compatible draft", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const gvtConfiguration: CycleConfiguration = {
      ...configuration("source_calculator_gvt", "standard"),
      template: {
        id: "source_calculator_gvt",
        variantId: "standard",
        options: {
          gvt_percentage: {
            overhead_press: 3000,
            deadlift: 3500,
            bench_press: 4000,
            squat: 4500,
          },
        },
      },
    };
    await repository.save(
      currentDraftId,
      draftEnvelope(metadata, cycleDraft(gvtConfiguration)),
    );

    const restored = await restoreCompatibleDraft(
      repository,
      metadata,
      new Map([["source_calculator_gvt", new Set(["standard"])]]),
    );
    expect(restored?.configuration).toEqual(gvtConfiguration);
    storage.close();
  });

  it("retains but does not restore a draft with unknown onePlusSet fields", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<unknown>(storage);
    const invalidConfiguration = {
      ...configuration(),
      maxes: {
        mode: "onePlusSet",
        globalTrainingMaxRatioBasisPoints: 9000,
        values: {
          squat: {
            weight: { centiUnits: 9500, unit: "kg" },
            repetitions: 1,
          },
        },
      },
    };
    await repository.save(currentDraftId, {
      ...metadata,
      payload: {
        draftVersion: cycleDraftVersion,
        configuration: invalidConfiguration,
      },
    });

    expect(
      await restoreCompatibleDraft(
        repository,
        metadata,
        new Map([["template", new Set(["variant"])]]),
      ),
    ).toBeUndefined();
    expect(await repository.list()).toHaveLength(1);
    storage.close();
  });

  it("keeps a current draft whose selection disappeared from the catalog", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const payload = cycleDraft(configuration("removed"));
    await repository.save(currentDraftId, draftEnvelope(metadata, payload));
    expect(await restoreCompatibleDraft(repository, metadata, new Map())).toBeUndefined();
    expect(await repository.list()).toHaveLength(1);
    storage.close();
  });

  it("migrates a compatible v1 draft in place without losing its values", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<unknown>(storage);
    await repository.save(currentDraftId, {
      ...metadata,
      payload: {
        draftVersion: 1,
        templateId: "template",
        variantId: "variant",
        scheduleId: "schedule",
        values: { templateId: "template", variantId: "variant", scheduleId: "schedule", ratio: 50 },
      },
    });

    const migratedPayload = cycleDraft(configuration());
    const restored = await restoreCompatibleDraft(
      repository,
      metadata,
      new Map([["template", new Set(["variant"])]]),
      () => migratedPayload,
    );
    expect(restored?.configuration).toEqual(configuration());
    const rewritten = await repository.load(currentDraftId);
    expect((rewritten?.envelope.payload as CycleDraftPayload).draftVersion).toBe(cycleDraftVersion);
    expect((rewritten?.envelope.payload as CycleDraftPayload)).toEqual(migratedPayload);
    storage.close();
  });

  it("retains an incompatible legacy draft when its migration codec declines it", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<unknown>(storage);
    const legacy = {
      draftVersion: 1,
      templateId: "template",
      variantId: "variant",
      values: { templateId: "template", variantId: "variant" },
    };
    await repository.save(currentDraftId, { ...metadata, payload: legacy });

    expect(await restoreCompatibleDraft(
      repository,
      metadata,
      new Map([["template", new Set(["variant"])]]),
      () => undefined,
    )).toBeUndefined();
    expect((await repository.load(currentDraftId))?.envelope.payload).toEqual(legacy);
    storage.close();
  });
});
