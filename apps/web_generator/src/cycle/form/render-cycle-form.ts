import {
  assertCycleEditorSchema,
  cycleFormRegions,
  fieldIsEnabled,
  fieldsByRegion,
  localized,
  valuesFromSchema,
} from "./schema";
import type {
  CycleEditorChoice,
  CycleEditorField,
  CycleFormIntentHandler,
  CycleFormRegion,
  JsonValue,
  RenderCycleFormOptions,
} from "./types";

const element = <K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
): HTMLElementTagNameMap[K] => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  return node;
};

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

function labelText(field: CycleEditorField, locale: string): HTMLLabelElement {
  const label = element("label");
  label.htmlFor = safeId(field.id);
  label.textContent = localized(field.label, locale);
  return label;
}

function applyCommonInput(
  input: HTMLInputElement,
  field: CycleEditorField,
  enabled: boolean,
): void {
  input.id = safeId(field.id);
  input.name = field.path;
  input.disabled = !enabled;
  if (field.minimum !== undefined) input.min = String(field.minimum);
  if (field.maximum !== undefined) input.max = String(field.maximum);
  if (field.step !== undefined) input.step = String(field.step);
}

function primitiveFromInput(field: CycleEditorField, input: HTMLInputElement): JsonValue {
  if (input.value === "") return null;
  if (field.kind === "integer") {
    return Number.isFinite(input.valueAsNumber) ? input.valueAsNumber : null;
  }
  if (["decimal", "percentage", "weight"].includes(field.kind)) {
    return Number.isFinite(input.valueAsNumber) ? input.valueAsNumber : null;
  }
  return input.value;
}

function choiceValue(choice: CycleEditorChoice): string {
  return JSON.stringify(choice.value);
}

function parseChoice(value: string): JsonValue {
  return JSON.parse(value) as JsonValue;
}

function renderSegmented(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const group = element("fieldset", "field");
  const legend = element("legend");
  legend.textContent = localized(field.label, locale);
  group.append(legend);
  const choices = element("div", "segmented-control");
  for (const choice of field.choices ?? []) {
    const wrapper = element("label");
    const input = element("input");
    input.type = "radio";
    input.name = field.path;
    input.value = choiceValue(choice);
    input.checked = JSON.stringify(field.value) === input.value;
    input.disabled = !enabled;
    input.addEventListener("change", () => {
      if (input.checked) emitChange(dispatch, schemaId, field, parseChoice(input.value));
    });
    wrapper.append(input, document.createTextNode(localized(choice.label, locale)));
    choices.append(wrapper);
  }
  group.append(choices);
  return group;
}

function renderBoolean(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const row = element("div", "switch-row");
  const label = labelText(field, locale);
  const input = element("input");
  input.type = "checkbox";
  applyCommonInput(input, field, enabled);
  input.checked = field.value === true;
  input.addEventListener("change", () =>
    emitChange(dispatch, schemaId, field, input.checked),
  );
  row.append(label, input);
  return row;
}

function renderSelect(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const wrapper = element("div", "field selection-field");
  const label = labelText(field, locale);
  const select = element("select");
  select.id = safeId(field.id);
  select.name = field.path;
  select.disabled = !enabled;
  for (const choice of field.choices ?? []) {
    const option = element("option");
    option.value = choiceValue(choice);
    option.textContent = localized(choice.label, locale);
    option.selected = JSON.stringify(field.value) === option.value;
    select.append(option);
  }
  select.addEventListener("change", () =>
    emitChange(dispatch, schemaId, field, parseChoice(select.value)),
  );
  wrapper.append(label, select);
  return wrapper;
}

function renderScalar(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const wrapper = element("div", "field");
  const label = labelText(field, locale);
  const input = element("input");
  input.type = field.kind === "date" ? "date" : field.kind === "text" ? "text" : "number";
  applyCommonInput(input, field, enabled);
  input.value = field.value === null ? "" : String(field.value);
  wrapper.append(label, input);
  input.addEventListener("change", () =>
    emitChange(dispatch, schemaId, field, primitiveFromInput(field, input)),
  );
  return wrapper;
}

function renderPlateCounter(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const wrapper = element("div", "field plate-counter");
  const title = element("span", "field-label");
  title.id = `${safeId(field.id)}-label`;
  title.textContent = localized(field.label, locale);
  const controls = element("div", "cluster");
  controls.setAttribute("role", "group");
  controls.setAttribute("aria-labelledby", title.id);
  const amount = element("output");
  amount.textContent = String(field.value);
  amount.setAttribute("aria-live", "polite");
  const step = field.step ?? 1;
  for (const [label, delta] of [["−", -step], ["+", step]] as const) {
    const button = element("button", "icon-action");
    button.type = "button";
    button.textContent = label;
    button.disabled = !enabled;
    button.setAttribute(
      "aria-label",
      delta < 0
        ? `− ${localized(field.label, locale)}`
        : `+ ${localized(field.label, locale)}`,
    );
    button.addEventListener("click", () => {
      const current = Number(amount.textContent);
      const next = Math.max(field.minimum ?? -Infinity, Math.min(field.maximum ?? Infinity, current + delta));
      amount.textContent = String(next);
      emitChange(dispatch, schemaId, field, next);
    });
    if (delta < 0) controls.append(button, amount);
    else controls.append(button);
  }
  wrapper.append(title, controls);
  return wrapper;
}

function renderTokenOrder(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const wrapper = element("fieldset", "field");
  const legend = element("legend");
  legend.textContent = localized(field.label, locale);
  const list = element("ol", "token-list");
  const values = Array.isArray(field.value) ? [...field.value] : [];
  values.forEach((value, index) => {
    const choice = field.choices?.find(
      (candidate) => JSON.stringify(candidate.value) === JSON.stringify(value),
    );
    const tokenLabel = choice ? localized(choice.label, locale) : String(value);
    const item = element("li");
    const button = element("button", "token");
    button.type = "button";
    button.disabled = !enabled;
    button.textContent = tokenLabel;
    button.setAttribute("aria-label", `${tokenLabel}, position ${index + 1}`);
    button.addEventListener("click", () => {
      if (index === 0) return;
      const previous = values[index - 1];
      const current = values[index];
      if (previous === undefined || current === undefined) return;
      values[index - 1] = current;
      values[index] = previous;
      emitChange(dispatch, schemaId, field, values);
    });
    item.append(button);
    list.append(item);
  });
  wrapper.append(legend, list);
  return wrapper;
}

function renderAction(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const button = element("button", "action");
  button.type = "button";
  button.disabled = !enabled;
  button.textContent = localized(field.label, locale);
  button.addEventListener("click", () => {
    void dispatch({
      type: "cycle.action.requested",
      schemaId,
      fieldId: field.id,
      action: field.action!,
    });
  });
  return button;
}

function renderField(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const rendered = field.kind === "boolean"
    ? renderBoolean(field, locale, enabled, schemaId, dispatch)
    : field.kind === "segmented"
      ? renderSegmented(field, locale, enabled, schemaId, dispatch)
      : field.kind === "choice"
        ? renderSelect(field, locale, enabled, schemaId, dispatch)
        : field.kind === "plate-counter"
          ? renderPlateCounter(field, locale, enabled, schemaId, dispatch)
          : field.kind === "token-order"
            ? renderTokenOrder(field, locale, enabled, schemaId, dispatch)
            : field.kind === "action"
              ? renderAction(field, locale, enabled, schemaId, dispatch)
              : renderScalar(field, locale, enabled, schemaId, dispatch);
  if (field.id === "template" || field.id === "variant") {
    rendered.dataset.testid = `${field.id}-row`;
  } else if (field.kind === "action") {
    rendered.dataset.testid = field.id;
  } else {
    const control = rendered.querySelector<HTMLElement>('input, select, button');
    if (control) control.dataset.testid = field.id;
  }
  return rendered;
}

function renderRegion(
  region: CycleFormRegion,
  fields: readonly CycleEditorField[],
  locale: string,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
  values: Readonly<Record<string, JsonValue>>,
): DocumentFragment {
  const fragment = document.createDocumentFragment();
  const groups = new Map<string, CycleEditorField[]>();
  for (const field of fields) {
    const key = field.group ?? "";
    groups.set(key, [...(groups.get(key) ?? []), field]);
  }
  const grouped = groups.size > 1 || (groups.size === 1 && !groups.has(""));
  const container = grouped && region === "additional-options" ? element("div", "options-grid") : element("div", "stack");
  for (const [groupId, groupFields] of groups) {
    const target = groupId ? element("fieldset", "stack") : container;
    if (groupId) {
      const legend = element("legend");
      const label = groupFields[0]?.groupLabel;
      legend.textContent = label ? localized(label, locale) : groupId;
      target.append(legend);
    }
    for (const field of groupFields) {
      target.append(renderField(field, locale, fieldIsEnabled(field, values), schemaId, dispatch));
    }
    if (target !== container) container.append(target);
  }
  fragment.append(container);
  return fragment;
}

export function renderCycleForm(options: RenderCycleFormOptions): () => void {
  const locale = options.locale ?? document.documentElement.lang ?? "en";
  assertCycleEditorSchema(options.schema);
  const values = valuesFromSchema(options.schema);
  const mounted: Element[] = [];
  for (const region of cycleFormRegions) {
    const mount = options.root.querySelector(`[data-cycle-mount="${region}"]`);
    if (!mount) throw new Error(`Missing Cycle form mount: ${region}`);
    mount.replaceChildren(
      renderRegion(
        region,
        fieldsByRegion(options.schema, region),
        locale,
        options.schema.id,
        options.dispatch,
        values,
      ),
    );
    mounted.push(mount);
  }
  return () => mounted.forEach((mount) => mount.replaceChildren());
}

export type { CycleEditorSchema, CycleFormIntent, RenderCycleFormOptions } from "./types";
