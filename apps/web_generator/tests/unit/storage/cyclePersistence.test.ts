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
    maxes: { mode: "oneRepMax", globalTrainingMaxRatioBasisPoints: 8500, values: {} },
    schedule: { id: "schedule", startDate: "2026-07-23", sessionOrder: [] },
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
