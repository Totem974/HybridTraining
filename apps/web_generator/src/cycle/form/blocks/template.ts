import { fieldIsEnabled, localized } from "../schema";
import type {
  CycleBlockRenderContext,
  CycleEditorField,
  CycleFormIntentHandler,
  JsonValue,
} from "../types";

const primarySelectionIds = new Set(["generation", "template", "variant"]);
const safeId = (value: string): string =>
  `cycle-field-${value.replace(/[^a-zA-Z0-9_-]/g, "-")}`;

function emitChange(
  dispatch: CycleFormIntentHandler,
  schemaId: string,
  field: CycleEditorField,
  value: JsonValue,
): void {
  void dispatch({
    type: "cycle.field.changed",
    schemaId,
    fieldId: field.id,
    path: field.path,
    value,
  });
}

function renderChoiceRow(
  field: CycleEditorField,
  context: CycleBlockRenderContext,
): HTMLElement {
  const row = document.createElement("div");
  row.className = "template-selection-row";
  row.dataset.testid = `${field.id}-row`;

  const label = document.createElement("label");
  label.className = "template-selection-label";
  label.htmlFor = safeId(field.id);
  label.textContent = localized(field.label, context.locale);

  const control = document.createElement("span");
  control.className = "template-selection-control";
  const select = document.createElement("select");
  select.id = safeId(field.id);
  select.name = field.path;
  select.disabled = !fieldIsEnabled(field, context.values);
  select.dataset.testid = field.id;
  select.setAttribute("aria-label", localized(field.label, context.locale));
  for (const choice of field.choices ?? []) {
    const option = document.createElement("option");
    option.value = JSON.stringify(choice.value);
    option.textContent = localized(choice.label, context.locale);
    option.selected = JSON.stringify(field.value) === option.value;
    select.append(option);
  }
  select.addEventListener("change", () => {
    emitChange(
      context.dispatch,
      context.schemaId,
      field,
      JSON.parse(select.value) as JsonValue,
    );
  });

  const chevron = document.createElement("span");
  chevron.className = "template-selection-chevron";
  chevron.setAttribute("aria-hidden", "true");
  chevron.textContent = "›";
  control.append(select, chevron);
  row.append(label, control);
  return row;
}

function renderBooleanOption(
  field: CycleEditorField,
  context: CycleBlockRenderContext,
): HTMLElement {
  const row = document.createElement("div");
  row.className = "switch-row template-option";
  const label = document.createElement("label");
  label.htmlFor = safeId(field.id);
  label.textContent = localized(field.label, context.locale);
  const input = document.createElement("input");
  input.type = "checkbox";
  input.id = safeId(field.id);
  input.name = field.path;
  input.checked = field.value === true;
  input.disabled = !fieldIsEnabled(field, context.values);
  input.dataset.testid = field.id;
  input.addEventListener("change", () => {
    emitChange(context.dispatch, context.schemaId, field, input.checked);
  });
  row.append(label, input);
  return row;
}

function renderDynamicOption(
  field: CycleEditorField,
  context: CycleBlockRenderContext,
): HTMLElement {
  if (field.kind === "boolean") return renderBooleanOption(field, context);
  if (field.kind === "choice") {
    const row = renderChoiceRow(field, context);
    row.classList.add("template-option");
    return row;
  }

  const wrapper = document.createElement("div");
  wrapper.className = "field template-option";
  const label = document.createElement("label");
  label.htmlFor = safeId(field.id);
  label.textContent = localized(field.label, context.locale);
  const input = document.createElement("input");
  input.id = safeId(field.id);
  input.name = field.path;
  input.type = field.kind === "text" ? "text" : "number";
  const percentageScale = field.kind === "percentage" ? 100 : 1;
  input.value = field.value == null
    ? ""
    : String(
        typeof field.value === "number"
          ? field.value / percentageScale
          : field.value,
      );
  input.disabled = !fieldIsEnabled(field, context.values);
  input.dataset.testid = field.id;
  if (field.minimum !== undefined) {
    input.min = String(field.minimum / percentageScale);
  }
  if (field.maximum !== undefined) {
    input.max = String(field.maximum / percentageScale);
  }
  if (field.step !== undefined) input.step = String(field.step / percentageScale);
  input.addEventListener("change", () => {
    const value = field.kind === "text"
      ? input.value
      : Number.isFinite(input.valueAsNumber)
        ? Math.round(input.valueAsNumber * percentageScale)
        : null;
    emitChange(context.dispatch, context.schemaId, field, value);
  });
  wrapper.append(label, input);
  if (field.kind === "percentage") {
    const unit = document.createElement("span");
    unit.className = "field-unit";
    unit.setAttribute("aria-hidden", "true");
    unit.textContent = "%";
    wrapper.append(unit);
  }
  return wrapper;
}

export function renderTemplateBlock(
  context: CycleBlockRenderContext,
): DocumentFragment {
  const fragment = document.createDocumentFragment();
  const block = document.createElement("div");
  block.className = "template-block";
  const rows = document.createElement("div");
  rows.className = "template-selection-rows";
  rows.setAttribute("role", "group");
  rows.setAttribute(
    "aria-label",
    context.locale.toLowerCase().startsWith("fr")
      ? "Sélection du programme"
      : "Program selection",
  );
  const options = document.createElement("div");
  options.className = "template-dynamic-options";

  for (const field of context.fields) {
    if (primarySelectionIds.has(field.id)) {
      rows.append(renderChoiceRow(field, context));
    } else {
      options.append(renderDynamicOption(field, context));
    }
  }
  if (rows.childElementCount > 0) block.append(rows);
  if (options.childElementCount > 0) {
    const optionsGroup = document.createElement("section");
    optionsGroup.className = "template-options-group";
    const heading = document.createElement("h3");
    heading.className = "template-options-heading";
    heading.id = `${safeId(context.schemaId)}-template-options`;
    heading.textContent = context.locale.toLowerCase().startsWith("fr")
      ? "Options du modèle"
      : "Template options";
    optionsGroup.setAttribute("aria-labelledby", heading.id);
    optionsGroup.append(heading, options);
    block.append(optionsGroup);
  }
  fragment.append(block);
  return fragment;
}
