import type { CycleBlockRenderer } from "../types";

const primaryGroups = ["warmup", "joker", "deload"] as const;

function groupClass(group: string): string {
  return group.replace(/[^a-zA-Z0-9_-]/g, "-");
}

function optionLabel(locale: string): string {
  return locale.toLowerCase().startsWith("fr") ? "Option" : "Option";
}

function primaryGroupLabel(group: typeof primaryGroups[number]): string {
  return group === "warmup"
    ? "WARM-UP"
    : group === "joker"
      ? "JOKER SETS"
      : "DELOAD";
}

function emptyPrimaryGroup(
  group: typeof primaryGroups[number],
  locale: string,
): HTMLFieldSetElement {
  const fieldset = document.createElement("fieldset");
  fieldset.dataset.optionGroup = group;
  fieldset.className = [
    "stack",
    "additional-options__group",
    `additional-options__group--${group}`,
    "additional-options__group--empty",
  ].join(" ");
  const legend = document.createElement("legend");
  legend.className = "additional-options__heading";
  legend.textContent = primaryGroupLabel(group);
  const message = document.createElement("p");
  message.className = "additional-options__empty";
  message.textContent = locale.toLowerCase().startsWith("fr")
    ? "Non disponible pour ce modèle"
    : "Not available for this template";
  fieldset.append(legend, message);
  return fieldset;
}

/**
 * Reshapes the generic schema renderer into the source-inspired three-column
 * layout. Field values, visibility, enabled state and controls remain entirely
 * owned by the engine schema and the shared renderer.
 */
export const renderAdditionalOptionsBlock: CycleBlockRenderer = (context) => {
  const rendered = context.renderDefault();
  const existingGrid = rendered.querySelector<HTMLElement>(".options-grid");
  const fallbackUngrouped = existingGrid
    ? []
    : [
        ...(rendered.firstElementChild?.children ?? []),
      ].filter((child): child is HTMLElement => child instanceof HTMLElement);
  const genericGrid = existingGrid ?? document.createElement("div");

  genericGrid.classList.add("additional-options");
  const primary = document.createElement("div");
  primary.className = "additional-options__primary";
  const secondary = document.createElement("div");
  secondary.className = "additional-options__secondary";

  const groups = [...new Set(context.fields.map((field) => field.group ?? ""))];
  const fieldsets = [...genericGrid.children].filter(
    (child): child is HTMLFieldSetElement => child instanceof HTMLFieldSetElement,
  );
  const fieldsetsByGroup = new Map<string, HTMLFieldSetElement>();
  let fieldsetIndex = 0;

  for (const group of groups) {
    if (!group) continue;
    const fieldset = fieldsets[fieldsetIndex++];
    if (!fieldset) continue;

    fieldset.dataset.optionGroup = group;
    fieldset.classList.add("additional-options__group", `additional-options__group--${groupClass(group)}`);
    fieldset.querySelector(":scope > legend")?.classList.add("additional-options__heading");
    fieldsetsByGroup.set(group, fieldset);

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
    if (!(primaryGroups as readonly string[]).includes(group)) secondary.append(fieldset);
  }

  for (const group of primaryGroups) {
    primary.append(
      fieldsetsByGroup.get(group) ?? emptyPrimaryGroup(group, context.locale),
    );
  }

  const ungrouped = [...genericGrid.children].filter(
    (child) => !(child instanceof HTMLFieldSetElement) && child !== primary && child !== secondary,
  );
  if (ungrouped.length > 0 || fallbackUngrouped.length > 0) {
    const miscellaneous = document.createElement("div");
    miscellaneous.className = "additional-options__group additional-options__group--miscellaneous";
    miscellaneous.append(...ungrouped, ...fallbackUngrouped);
    secondary.append(miscellaneous);
  }

  genericGrid.replaceChildren(primary);
  if (secondary.childElementCount > 0) genericGrid.append(secondary);
  if (!rendered.contains(genericGrid)) {
    rendered.replaceChildren(genericGrid);
  }
  return rendered;
};
