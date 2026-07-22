import { IDBFactory } from "fake-indexeddb";
import { describe, expect, it } from "vitest";

import {
  IndexedDbWorkspaceStorage,
  PreferencesStore,
  SavedConfigurationRepository,
  TrainingSnapshotRepository,
  WorkspaceDraftRepository,
  exportConfiguration,
  exportEnvelope,
  exportProgram,
  importEnvelope,
  importValidatedArtifact,
  workspaceStores,
  type EnvelopeLike,
  type StorageLike,
} from "../../../src/storage";

const envelope: EnvelopeLike<{ weeks: number[] }> = {
  apiVersion: "v1",
  engineVersion: "1.0.0",
  catalogVersion: 1,
  catalogHash: "abc",
  schemaVersion: 1,
  payload: { weeks: [1, 2, 3] },
};

describe("versioned envelope import/export", () => {
  it("round-trips without mutating the snapshot", () => {
    const before = structuredClone(envelope);
    const exported = exportEnvelope(envelope);
    const imported = importEnvelope<typeof envelope.payload>(exported);

    expect(envelope).toEqual(before);
    expect(imported).toEqual(envelope);
    expect(imported).not.toBe(envelope);
    expect(imported.payload).not.toBe(envelope.payload);
  });

  it("rejects unversioned data", () => {
    expect(() => importEnvelope('{"payload":{}}')).toThrow(TypeError);
  });
});

describe("local artifact import/export", () => {
  const configuration = { ...envelope, artifactKind: "configuration" as const };
  const program = { ...envelope, artifactKind: "program" as const };

  it("exports configurations and programs without changing their payload", () => {
    expect(JSON.parse(exportConfiguration(configuration))).toEqual(configuration);
    expect(JSON.parse(exportProgram(program))).toEqual(program);
    expect(() => exportConfiguration(program)).toThrow(TypeError);
    expect(() => exportProgram(configuration)).toThrow(TypeError);
  });

  it("requires successful local-engine validation on import", async () => {
    let calls = 0;
    const imported = await importValidatedArtifact(
      JSON.stringify(configuration),
      "configuration",
      (candidate) => {
        calls += 1;
        expect(candidate.payload).toEqual(envelope.payload);
        return { valid: true, errors: [] };
      },
    );

    expect(calls).toBe(1);
    expect(imported).toEqual(configuration);
    expect(imported).not.toBe(configuration);
    await expect(
      importValidatedArtifact(JSON.stringify(program), "configuration", () => ({
        valid: true,
      })),
    ).rejects.toThrow(TypeError);
    await expect(
      importValidatedArtifact(JSON.stringify(configuration), "configuration", () => ({
        valid: false,
        errors: [{ code: "INVALID" }],
      })),
    ).rejects.toThrow("rejected by the local engine");
  });
});

describe("PreferencesStore", () => {
  it("writes only the three allowed local preferences", () => {
    const storage = new MemoryStorage();
    const preferences = new PreferencesStore(storage);

    preferences.setLocale("en");
    preferences.setCollapsedSections(["weight", "weight", "bad id"]);
    preferences.setShowPlating(false);

    expect(storage.keys()).toEqual([
      "hybridTraining.collapsedSections",
      "hybridTraining.locale",
      "hybridTraining.showPlating",
    ]);
    expect(preferences.read()).toEqual({
      locale: "en",
      collapsedSections: ["weight"],
      showPlating: false,
    });
  });
});

describe("IndexedDbWorkspaceStorage", () => {
  it("creates and isolates all versioned workspace stores", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const original = structuredClone(envelope);

    for (const [index, store] of workspaceStores.entries()) {
      await storage.put(store, {
        id: `item-${index}`,
        updatedAt: `2026-07-2${index}T00:00:00.000Z`,
        envelope,
      });
      expect((await storage.list(store)).map((item) => item.id)).toEqual([
        `item-${index}`,
      ]);
    }

    const loaded = await storage.get("training_snapshots", "item-2");
    expect(loaded?.envelope).toEqual(envelope);
    expect(loaded?.envelope).not.toBe(envelope);
    expect(envelope).toEqual(original);
    storage.close();
  });

  it("rejects malformed records before writing", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    await expect(
      storage.put("workspace_drafts", {
        id: "bad",
        updatedAt: "not-a-date",
        envelope,
      }),
    ).rejects.toThrow(TypeError);
    await expect(
      storage.put("workspace_drafts", {
        id: "bad-envelope",
        updatedAt: "2026-07-22T00:00:00.000Z",
        envelope: { payload: {} } as EnvelopeLike,
      }),
    ).rejects.toThrow(TypeError);
    storage.close();
  });

  it("provides one typed repository per required store", async () => {
    const storage = new IndexedDbWorkspaceStorage(new IDBFactory());
    const repositories = [
      new WorkspaceDraftRepository(storage),
      new SavedConfigurationRepository(storage),
      new TrainingSnapshotRepository(storage),
    ];

    for (const [index, repository] of repositories.entries()) {
      await repository.save(
        `repository-${index}`,
        envelope,
        new Date(`2026-07-2${index}T00:00:00.000Z`),
      );
      expect((await repository.load(`repository-${index}`))?.envelope).toEqual(
        envelope,
      );
    }
    storage.close();
  });
});

class MemoryStorage implements StorageLike {
  private readonly values = new Map<string, string>();

  getItem(key: string): string | null {
    return this.values.get(key) ?? null;
  }
  setItem(key: string, value: string): void {
    this.values.set(key, value);
  }
  removeItem(key: string): void {
    this.values.delete(key);
  }
  keys(): string[] {
    return [...this.values.keys()].sort();
  }
}
