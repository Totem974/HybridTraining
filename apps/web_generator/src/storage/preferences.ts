export type Locale = "fr" | "en";

export interface LocalPreferences {
  readonly locale: Locale;
  readonly collapsedSections: readonly string[];
  readonly showPlating: boolean;
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

const keys = {
  locale: "hybridTraining.locale",
  collapsedSections: "hybridTraining.collapsedSections",
  showPlating: "hybridTraining.showPlating",
} as const;

export class PreferencesStore {
  constructor(private readonly storage: StorageLike = localStorage) {}

  read(): LocalPreferences {
    return {
      locale: this.readLocale(),
      collapsedSections: this.readCollapsedSections(),
      showPlating: this.storage.getItem(keys.showPlating) !== "false",
    };
  }

  setLocale(locale: Locale): void {
    this.storage.setItem(keys.locale, locale);
  }

  setCollapsedSections(sectionIds: readonly string[]): void {
    const normalized = [...new Set(sectionIds.filter(isSafeSectionId))];
    this.storage.setItem(keys.collapsedSections, JSON.stringify(normalized));
  }

  setShowPlating(show: boolean): void {
    this.storage.setItem(keys.showPlating, String(show));
  }

  clear(): void {
    Object.values(keys).forEach((key) => this.storage.removeItem(key));
  }

  private readLocale(): Locale {
    return this.storage.getItem(keys.locale) === "en" ? "en" : "fr";
  }

  private readCollapsedSections(): readonly string[] {
    try {
      const value: unknown = JSON.parse(
        this.storage.getItem(keys.collapsedSections) ?? "[]",
      );
      return Array.isArray(value) ? value.filter(isSafeSectionId) : [];
    } catch {
      return [];
    }
  }
}

function isSafeSectionId(value: unknown): value is string {
  return typeof value === "string" && /^[a-z][a-z0-9-]*$/.test(value);
}
