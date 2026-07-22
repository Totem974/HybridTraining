import { IDBFactory } from "fake-indexeddb";
import { describe, expect, it } from "vitest";

import {
  IndexedDbWorkspaceStorage,
  PreferencesStore,
  exportEnvelope,
  importEnvelope,
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
