import { clone, type EnvelopeLike } from "./envelope";

export const databaseName = "hybrid-training-web";
export const databaseVersion = 1;
export const workspaceStores = [
  "workspace_drafts",
  "saved_configurations",
  "training_snapshots",
] as const;

export type WorkspaceStoreName = (typeof workspaceStores)[number];

export interface StoredEnvelope<T = unknown> {
  readonly id: string;
  readonly updatedAt: string;
  readonly envelope: EnvelopeLike<T>;
}

export class IndexedDbWorkspaceStorage {
  private databasePromise?: Promise<IDBDatabase>;

  constructor(private readonly factory: IDBFactory = indexedDB) {}

  async put<T>(store: WorkspaceStoreName, item: StoredEnvelope<T>): Promise<void> {
    requireId(item.id);
    const db = await this.open();
    await request(db.transaction(store, "readwrite").objectStore(store).put(clone(item)));
  }

  async get<T>(store: WorkspaceStoreName, id: string): Promise<StoredEnvelope<T> | undefined> {
    requireId(id);
    const db = await this.open();
    const result = await request<StoredEnvelope<T> | undefined>(
      db.transaction(store, "readonly").objectStore(store).get(id),
    );
    return result === undefined ? undefined : clone(result);
  }

  async list<T>(store: WorkspaceStoreName): Promise<readonly StoredEnvelope<T>[]> {
    const db = await this.open();
    const result = await request<StoredEnvelope<T>[]>(
      db.transaction(store, "readonly").objectStore(store).getAll(),
    );
    return clone(result).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  async delete(store: WorkspaceStoreName, id: string): Promise<void> {
    requireId(id);
    const db = await this.open();
    await request(db.transaction(store, "readwrite").objectStore(store).delete(id));
  }

  async clear(store: WorkspaceStoreName): Promise<void> {
    const db = await this.open();
    await request(db.transaction(store, "readwrite").objectStore(store).clear());
  }

  close(): void {
    void this.databasePromise?.then((database) => database.close());
    this.databasePromise = undefined;
  }

  private open(): Promise<IDBDatabase> {
    this.databasePromise ??= new Promise((resolve, reject) => {
      const opening = this.factory.open(databaseName, databaseVersion);
      opening.onupgradeneeded = () => {
        for (const store of workspaceStores) {
          if (!opening.result.objectStoreNames.contains(store)) {
            opening.result.createObjectStore(store, { keyPath: "id" });
          }
        }
      };
      opening.onsuccess = () => resolve(opening.result);
      opening.onerror = () => reject(opening.error ?? new Error("Unable to open IndexedDB"));
      opening.onblocked = () => reject(new Error("IndexedDB upgrade blocked"));
    });
    return this.databasePromise;
  }
}

function request<T>(operation: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    operation.onsuccess = () => resolve(operation.result);
    operation.onerror = () => reject(operation.error ?? new Error("IndexedDB operation failed"));
  });
}

function requireId(id: string): void {
  if (id.trim() === "") throw new TypeError("A storage id is required");
}
