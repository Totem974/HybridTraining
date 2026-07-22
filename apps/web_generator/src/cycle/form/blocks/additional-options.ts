import type { CycleBlockRenderer } from "../types";

const primaryGroups = ["warmup", "joker", "deload"] as const;

function groupClass(group: string): string {
  return group.replace(/[^a-zA-Z0-9_-]/g, "-");
}

function optionLabel(locale: string): string {
  return locale.toLowerCase().startsWith("fr") ? "Option" : "Option";
}

/**
 * Reshapes the generic schema renderer into the source-inspired three-column
 * layout. Field values, visibility, enabled state and controls remain entirely
 * owned by the engine schema and the shared renderer.
 */
export const renderAdditionalOptionsBlock: CycleBlockRenderer = (context) => {
  const rendered = context.renderDefault();
  const genericGrid = rendered.querySelector<HTMLElement>(".options-grid");
  if (!genericGrid) return rendered;

  genericGrid.classList.add("additional-options");
  const primary = document.createElement("div");
  primary.className = "additional-options__primary";
  const secondary = document.createElement("div");
  secondary.className = "additional-options__secondary";

  const groups = [...new Set(context.fields.map((field) => field.group ?? ""))];
  const fieldsets = [...genericGrid.children].filter(
    (child): child is HTMLFieldSetElement => child instanceof HTMLFieldSetElement,
  );
  let fieldsetIndex = 0;

  for (const group of groups) {
    if (!group) continue;
    const fieldset = fieldsets[fieldsetIndex++];
    if (!fieldset) continue;

    fieldset.dataset.optionGroup = group;
    fieldset.classList.add("additional-options__group", `additional-options__group--${groupClass(group)}`);
    fieldset.querySelector(":scope > legend")?.classList.add("additional-options__heading");

    for (const row of fieldset.querySelectorAll<HTMLElement>(":scope > .switch-row")) {
      row.classList.add("additional-options__switch-row");
      const caption = document.createElement("span");
      caption.className = "additional-options__option-label";
      caption.textContent = optionLabel(context.locale);
      caption.setAttribute("aria-hidden", "true");
      row.prepend(caption);
    }

    if (group === "hidden") {
      fieldset.hidden = true;
      continue;
    }
    if ((primaryGroups as readonly string[]).includes(group)) primary.append(fieldset);
    else secondary.append(fieldset);
  }

  const ungrouped = [...genericGrid.children].filter(
    (child) => !(child instanceof HTMLFieldSetElement) && child !== primary && child !== secondary,
  );
  if (ungrouped.length > 0) {
    const miscellaneous = document.createElement("div");
    miscellaneous.className = "additional-options__group additional-options__group--miscellaneous";
    miscellaneous.append(...ungrouped);
    secondary.append(miscellaneous);
  }

  genericGrid.replaceChildren(primary);
  if (secondary.childElementCount > 0) genericGrid.append(secondary);
  return rendered;
};
