import { fieldIsEnabled, localized } from "../schema";
import type {
  CycleBlockRenderContext,
  CycleBlockRenderer,
  CycleEditorChoice,
  CycleEditorField,
  JsonValue,
} from "../types";

const node = <K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
): HTMLElementTagNameMap[K] => {
  const element = document.createElement(tag);
  if (className) element.className = className;
  return element;
};

const controlId = (field: CycleEditorField): string =>
  `plating-${field.id.replace(/[^a-zA-Z0-9_-]/g, "-")}`;

function dispatchValue(
  context: CycleBlockRenderContext,
  field: CycleEditorField,
  value: JsonValue,
): void {
  void context.dispatch({
    type: "cycle.field.changed",
    schemaId: context.schemaId,
    fieldId: field.id,
    path: field.path,
    value,
  });
}

function choiceKey(choice: CycleEditorChoice): string {
  return JSON.stringify(choice.value);
}

function renderChoice(
  context: CycleBlockRenderContext,
  field: CycleEditorField,
): HTMLElement {
  const wrapper = node("div", "plating-setting");
  const label = node("label");
  label.htmlFor = controlId(field);
  label.textContent = localized(field.label, context.locale);
  const select = node("select");
  select.id = controlId(field);
  select.name = field.path;
  select.disabled = !fieldIsEnabled(field, context.values);
  select.dataset.testid = field.id;
  for (const choice of field.choices ?? []) {
    const option = node("option");
    option.value = choiceKey(choice);
    option.textContent = localized(choice.label, context.locale);
    option.selected = JSON.stringify(field.value) === option.value;
    select.append(option);
  }
  select.addEventListener("change", () => {
    dispatchValue(context, field, JSON.parse(select.value) as JsonValue);
  });
  wrapper.append(label, select);
  return wrapper;
}

function renderSegmented(
  context: CycleBlockRenderContext,
  field: CycleEditorField,
): HTMLElement {
  const group = node("fieldset", "plating-setting plating-unit");
  const legend = node("legend");
  legend.textContent = localized(field.label, context.locale);
  const choices = node("div", "plating-unit__choices");
  for (const choice of field.choices ?? []) {
    const label = node("label");
    const input = node("input");
    input.type = "radio";
    input.name = field.path;
    input.value = choiceKey(choice);
    input.checked = JSON.stringify(field.value) === input.value;
    input.disabled = !fieldIsEnabled(field, context.values);
    input.dataset.testid = `${field.id}-${String(choice.value)}`;
    input.addEventListener("change", () => {
      if (input.checked) dispatchValue(context, field, choice.value);
    });
    label.append(input, document.createTextNode(localized(choice.label, context.locale)));
    choices.append(label);
  }
  group.append(legend, choices);
  return group;
}

function renderCounter(
  context: CycleBlockRenderContext,
  field: CycleEditorField,
): HTMLElement {
  const wrapper = node("div", "plating-counter");
  const label = node("span", "plating-counter__label");
  label.id = `${controlId(field)}-label`;
  label.textContent = localized(field.label, context.locale);

  const controls = node("div", "plating-counter__controls");
  controls.setAttribute("role", "group");
  controls.setAttribute("aria-labelledby", label.id);
  const output = node("output", "plating-counter__quantity");
  output.value = String(field.value);
  output.textContent = String(field.value);
  output.setAttribute("aria-live", "polite");
  const enabled = fieldIsEnabled(field, context.values);
  const increment = field.step ?? 1;

  const button = (symbol: string, delta: number): HTMLButtonElement => {
    const result = node("button", "plating-counter__button");
    result.type = "button";
    result.textContent = symbol;
    result.disabled = !enabled;
    result.dataset.testid = `${field.id}-${delta < 0 ? "decrement" : "increment"}`;
    const action = delta < 0
      ? context.locale.startsWith("fr") ? "Retirer" : "Remove"
      : context.locale.startsWith("fr") ? "Ajouter" : "Add";
    result.setAttribute("aria-label", `${action} ${localized(field.label, context.locale)}`);
    result.addEventListener("click", () => {
      const current = Number(output.value);
      const next = Math.max(
        field.minimum ?? Number.NEGATIVE_INFINITY,
        Math.min(field.maximum ?? Number.POSITIVE_INFINITY, current + delta),
      );
      output.value = String(next);
      output.textContent = String(next);
      dispatchValue(context, field, next);
    });
    return result;
  };

  controls.append(button("−", -increment), output, button("+", increment));
  wrapper.append(label, controls);
  return wrapper;
}

function renderSummaryField(
  context: CycleBlockRenderContext,
  field: CycleEditorField,
  position: "bar" | "maximum",
): HTMLElement {
  const wrapper = node("div", `plating-summary__item plating-summary__item--${position}`);
  const label = node("label");
  label.htmlFor = controlId(field);
  label.textContent = localized(field.label, context.locale);

  if (field.readOnly) {
    const output = node("output", "plating-summary__value");
    output.id = controlId(field);
    output.value = String(field.value ?? "");
    output.textContent = String(field.value ?? "");
    wrapper.append(label, output);
  } else {
    const input = node("input", "plating-summary__input");
    input.id = controlId(field);
    input.name = field.path;
    input.type = "number";
    input.value = String(field.value ?? "");
    input.disabled = !fieldIsEnabled(field, context.values);
    input.dataset.testid = field.id;
    if (field.minimum !== undefined) input.min = String(field.minimum);
    if (field.maximum !== undefined) input.max = String(field.maximum);
    if (field.step !== undefined) input.step = String(field.step);
    input.addEventListener("change", () => {
      dispatchValue(context, field, Number.isFinite(input.valueAsNumber) ? input.valueAsNumber : null);
    });
    wrapper.append(label, input);
  }
  return wrapper;
}

function isBarField(field: CycleEditorField): boolean {
  return field.id === "bar-weight" || /(?:^|\.)barWeight$/.test(field.path);
}

function isMaximumField(field: CycleEditorField): boolean {
  return field.id === "maximum-plate-load" || /maximum.*(?:load|total)/i.test(field.path);
}

export const renderPlatingBlock: CycleBlockRenderer = (context) => {
  const fragment = document.createDocumentFragment();
  const block = node("div", "plating-block");
  const settings = node("div", "plating-settings");
  const plateGrid = node("div", "plating-grid");
  const summary = node("div", "plating-summary");

  const bar = context.fields.find(isBarField);
  const maximum = context.fields.find(isMaximumField);
  for (const field of context.fields) {
    if (field === bar || field === maximum) continue;
    if (field.kind === "plate-counter") {
      plateGrid.append(renderCounter(context, field));
    } else if (field.kind === "segmented") {
      settings.append(renderSegmented(context, field));
    } else if (field.kind === "choice") {
      settings.append(renderChoice(context, field));
    }
  }

  if (settings.childElementCount > 0) block.append(settings);
  if (plateGrid.childElementCount > 0) block.append(plateGrid);
  if (bar) summary.append(renderSummaryField(context, bar, "bar"));
  if (maximum) summary.append(renderSummaryField(context, maximum, "maximum"));
  if (summary.childElementCount > 0) block.append(summary);
  fragment.append(block);
  return fragment;
};
