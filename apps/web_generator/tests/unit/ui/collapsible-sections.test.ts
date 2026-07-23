import { beforeEach, describe, expect, it } from "vitest";

import { installCollapsibleSections } from "../../../src/cycle/ui/collapsibleSections";
import { PreferencesStore, type StorageLike } from "../../../src/storage/preferences";

describe("collapsible cycle sections", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <section data-collapsible-section="additional-options">
        <button data-collapse-toggle aria-expanded="true">Additional options</button>
        <div data-collapse-content>Options</div>
      </section>
      <section data-collapsible-section="plating">
        <button data-collapse-toggle aria-expanded="true">Plating</button>
        <div data-collapse-content>Plates</div>
      </section>
    `;
  });

  it("restores collapsed state and exposes it accessibly", () => {
    const storage = new MemoryStorage();
    const preferences = new PreferencesStore(storage);
    preferences.setCollapsedSections(["plating"]);

    installCollapsibleSections(document, preferences);

    const sections = document.querySelectorAll<HTMLElement>("[data-collapsible-section]");
    expect(sections[0]?.querySelector("[data-collapse-content]")?.hasAttribute("hidden")).toBe(false);
    expect(sections[1]?.querySelector("[data-collapse-content]")?.hasAttribute("hidden")).toBe(true);
    expect(sections[1]?.querySelector("button")?.getAttribute("aria-expanded")).toBe("false");
  });

  it("persists toggles and removes its event listeners on dispose", () => {
    const preferences = new PreferencesStore(new MemoryStorage());
    const dispose = installCollapsibleSections(document, preferences);
    const toggle = document.querySelector<HTMLButtonElement>(
      '[data-collapsible-section="additional-options"] button',
    )!;

    toggle.click();
    expect(preferences.read().collapsedSections).toEqual(["additional-options"]);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");

    dispose();
    toggle.click();
    expect(preferences.read().collapsedSections).toEqual(["additional-options"]);
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
}
