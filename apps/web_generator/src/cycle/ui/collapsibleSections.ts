import type { PreferencesStore } from "../../storage/preferences";

const selector = "[data-collapsible-section]";

export function installCollapsibleSections(
  root: ParentNode,
  preferences: Pick<PreferencesStore, "read" | "setCollapsedSections">,
): () => void {
  const sections = [...root.querySelectorAll<HTMLElement>(selector)];
  const allowedIds = new Set(
    sections
      .map((section) => section.dataset.collapsibleSection)
      .filter((id): id is string => Boolean(id)),
  );
  const collapsed = new Set(
    preferences.read().collapsedSections.filter((id) => allowedIds.has(id)),
  );
  const cleanups: Array<() => void> = [];

  const apply = (section: HTMLElement, isCollapsed: boolean): void => {
    const toggle = section.querySelector<HTMLButtonElement>("[data-collapse-toggle]");
    const content = section.querySelector<HTMLElement>("[data-collapse-content]");
    if (!toggle || !content) return;
    toggle.setAttribute("aria-expanded", String(!isCollapsed));
    content.hidden = isCollapsed;
    section.classList.toggle("is-collapsed", isCollapsed);
  };

  for (const section of sections) {
    const id = section.dataset.collapsibleSection;
    if (!id) continue;
    const toggle = section.querySelector<HTMLButtonElement>("[data-collapse-toggle]");
    if (!toggle) continue;
    apply(section, collapsed.has(id));
    const onClick = (): void => {
      if (collapsed.has(id)) collapsed.delete(id);
      else collapsed.add(id);
      apply(section, collapsed.has(id));
      preferences.setCollapsedSections([...collapsed]);
    };
    toggle.addEventListener("click", onClick);
    cleanups.push(() => toggle.removeEventListener("click", onClick));
  }

  return () => cleanups.forEach((cleanup) => cleanup());
}
