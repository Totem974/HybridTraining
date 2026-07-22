import type { EnvelopeLike } from "./envelope";
import {
  IndexedDbWorkspaceStorage,
  type StoredEnvelope,
  type WorkspaceStoreName,
} from "./indexedDbStorage";

export class VersionedEnvelopeRepository<T> {
  constructor(
    private readonly storage: IndexedDbWorkspaceStorage,
    private readonly store: WorkspaceStoreName,
  ) {}

  save(id: string, envelope: EnvelopeLike<T>, updatedAt = new Date()): Promise<void> {
    return this.storage.put(this.store, {
      id,
      updatedAt: updatedAt.toISOString(),
      envelope,
    });
  }

  load(id: string): Promise<StoredEnvelope<T> | undefined> {
    return this.storage.get<T>(this.store, id);
  }

  list(): Promise<readonly StoredEnvelope<T>[]> {
    return this.storage.list<T>(this.store);
  }

  delete(id: string): Promise<void> {
    return this.storage.delete(this.store, id);
  }

  clear(): Promise<void> {
    return this.storage.clear(this.store);
  }
}

export class WorkspaceDraftRepository<T> extends VersionedEnvelopeRepository<T> {
  constructor(storage: IndexedDbWorkspaceStorage) {
    super(storage, "workspace_drafts");
  }
}

export class SavedConfigurationRepository<T> extends VersionedEnvelopeRepository<T> {
  constructor(storage: IndexedDbWorkspaceStorage) {
    super(storage, "saved_configurations");
  }
}

export class TrainingSnapshotRepository<T> extends VersionedEnvelopeRepository<T> {
  constructor(storage: IndexedDbWorkspaceStorage) {
    super(storage, "training_snapshots");
  }
}
