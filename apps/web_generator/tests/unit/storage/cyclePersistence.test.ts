import { IDBFactory } from "fake-indexeddb";
import { describe, expect, it } from "vitest";

import {
  currentDraftId,
  cycleDraft,
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

describe("Cycle draft persistence", () => {
  it("restores a compatible draft and removes obsolete records", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const payload = cycleDraft({
      templateId: "template",
      variantId: "variant",
      scheduleId: "schedule",
      "options.warmup": true,
    });
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
    expect(restored).toEqual(payload);
    expect((await repository.list()).map((record) => record.id)).toEqual([currentDraftId]);
    storage.close();
  });

  it("cleans a current draft whose selection disappeared from the catalog", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repository = new WorkspaceDraftRepository<CycleDraftPayload>(storage);
    const payload = cycleDraft({ templateId: "removed", variantId: "variant" });
    await repository.save(currentDraftId, draftEnvelope(metadata, payload));
    expect(await restoreCompatibleDraft(repository, metadata, new Map())).toBeUndefined();
    expect(await repository.list()).toEqual([]);
    storage.close();
  });
});
