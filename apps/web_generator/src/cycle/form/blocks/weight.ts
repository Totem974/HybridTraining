import "../../../../styles/blocks/weight.css";

import { fieldIsEnabled, fieldIsVisible, localized } from "../schema";
import type {
  CycleEditorField,
  CycleFormIntentHandler,
  JsonValue,
} from "../types";

export interface RenderWeightBlockOptions {
  readonly fields: readonly CycleEditorField[];
  readonly values: Readonly<Record<string, JsonValue>>;
  readonly locale: string;
  readonly schemaId: string;
  readonly dispatch: CycleFormIntentHandler;
}

export function renderWeightBlock(options: RenderWeightBlockOptions): HTMLElement {
  const block = node("div", "weight-block");
  const mode = options.fields.find(
    (field) => field.kind === "segmented" && field.path !== "unit",
  );
  const unit = options.fields.find((field) => field.path === "unit");
  const ratio = options.fields.find(
    (field) => field.path === "globalTrainingMaxRatioBasisPoints",
  );
  const loads = options.fields.filter((field) => isMovementPath(field.path, "weight"));
  const repetitions = new Map(
    options.fields
      .filter((field) => isMovementPath(field.path, "repetitions"))
      .map((field) => [movementKey(field.path), field]),
  );

  if (mode) block.append(renderSegmented(mode, options, "weight-mode"));

  const activeMode = mode?.choices?.find(
    (choice) => JSON.stringify(choice.value) === JSON.stringify(mode.value),
  );
  const oneRepMode = mode?.choices?.[0];
  const isOneRepMode = activeMode !== undefined && activeMode === oneRepMode;
  const unitLabel = selectedChoiceLabel(unit, options.locale);
  const movementList = node("div", "weight-movements");

  for (const load of loads) {
    const movement = movementKey(load.path);
    const reps = repetitions.get(movement);
    movementList.append(
      renderMovementRow(load, reps, unitLabel, isOneRepMode, options),
    );
  }
  block.append(movementList);

  if (ratio && isOneRepMode && fieldIsVisible(ratio, options.values)) {
    block.append(renderRatio(ratio, options));
  }
  if (unit) block.append(renderSegmented(unit, options, "weight-unit"));
  return block;
}

function renderMovementRow(
  load: CycleEditorField,
  repetitions: CycleEditorField | undefined,
  unitLabel: string,
  oneRepMode: boolean,
  options: RenderWeightBlockOptions,
): HTMLElement {
  const row = node("div", "weight-movement");
  const marker = node("span", "weight-movement__marker");
  marker.setAttribute("aria-hidden", "true");
  const name = node("label", "weight-movement__name");
  name.htmlFor = controlId(load);
  name.textContent = localized(load.label, options.locale);
  row.append(marker, name);

  const controls = node("div", "weight-movement__controls");
  if (oneRepMode) {
    controls.append(readonlyRepetitions("1", options.locale));
  } else if (repetitions && fieldIsVisible(repetitions, options.values)) {
    const input = numberInput(repetitions, options, "weight-repetitions");
    input.setAttribute(
      "aria-label",
      `${localized(load.label, options.locale)} — ${localized(repetitions.label, options.locale)}`,
    );
    controls.append(input);
  } else {
    const placeholder = node("span", "weight-repetitions-placeholder");
    placeholder.setAttribute("aria-hidden", "true");
    controls.append(placeholder);
  }
  controls.append(numberInput(load, options, "weight-load"));
  const unit = node("span", "weight-movement__unit");
  unit.textContent = unitLabel;
  controls.append(unit);
  row.append(controls);
  return row;
}

function renderRatio(
  field: CycleEditorField,
  options: RenderWeightBlockOptions,
): HTMLElement {
  const wrapper = node("div", "weight-ratio");
  const label = node("label", "weight-ratio__label");
  label.htmlFor = controlId(field);
  label.textContent = localized(field.label, options.locale);
  const input = numberInput(field, options, "weight-ratio__input", 100);
  const suffix = node("span", "weight-ratio__suffix");
  suffix.textContent = "%";
  wrapper.append(label, input, suffix);
  return wrapper;
}

function renderSegmented(
  field: CycleEditorField,
  options: RenderWeightBlockOptions,
  className: string,
): HTMLElement {
  const fieldset = node("fieldset", `weight-segmented ${className}`);
  const legend = node("legend", "visually-hidden");
  legend.textContent = localized(field.label, options.locale);
  const choices = node("div", "segmented-control");
  for (const [index, choice] of (field.choices ?? []).entries()) {
    const label = node("label", "weight-segmented__choice");
    const input = document.createElement("input");
    input.type = "radio";
    input.name = field.path;
    input.value = JSON.stringify(choice.value);
    input.checked = JSON.stringify(field.value) === input.value;
    input.disabled = !fieldIsEnabled(field, options.values);
    input.dataset.testid = index === 0 ? field.id : `${field.id}-${index}`;
    input.addEventListener("change", () => {
      if (input.checked) emit(options, field, choice.value);
    });
    label.append(input, document.createTextNode(localized(choice.label, options.locale)));
    choices.append(label);
  }
  fieldset.append(legend, choices);
  return fieldset;
}

function numberInput(
  field: CycleEditorField,
  options: RenderWeightBlockOptions,
  className: string,
  scale = 1,
): HTMLInputElement {
  const input = document.createElement("input");
  input.className = className;
  input.id = controlId(field);
  input.name = field.path;
  input.type = "number";
  input.inputMode = "decimal";
  input.disabled = !fieldIsEnabled(field, options.values);
  input.dataset.testid = field.id;
  if (typeof field.value === "number") input.value = String(field.value / scale);
  if (field.minimum !== undefined) input.min = String(field.minimum / scale);
  if (field.maximum !== undefined) input.max = String(field.maximum / scale);
  if (field.step !== undefined) input.step = String(field.step / scale);
  input.addEventListener("change", () => {
    emit(options, field, input.value === "" ? null : input.valueAsNumber * scale);
  });
  return input;
}

function readonlyRepetitions(value: string, locale: string): HTMLElement {
  const output = node("span", "weight-repetitions weight-repetitions--fixed");
  output.textContent = value;
  output.setAttribute("aria-label", `${value} ${locale.startsWith("fr") ? "répétition" : "repetition"}`);
  return output;
}

function selectedChoiceLabel(
  field: CycleEditorField | undefined,
  locale: string,
): string {
  const choice = field?.choices?.find(
    (candidate) => JSON.stringify(candidate.value) === JSON.stringify(field.value),
  );
  return choice ? localized(choice.label, locale) : "";
}

function emit(
  options: RenderWeightBlockOptions,
  field: CycleEditorField,
  value: JsonValue,
): void {
  void options.dispatch({
    type: "cycle.field.changed",
    schemaId: options.schemaId,
    fieldId: field.id,
    path: field.path,
    value,
  });
}

function isMovementPath(path: string, leaf: string): boolean {
  const parts = path.split(".");
  return parts.length === 3 && parts[0] === "maxInputs" && parts[2] === leaf;
}

function movementKey(path: string): string {
  return path.split(".")[1] ?? "";
}

function controlId(field: CycleEditorField): string {
  return `cycle-field-${field.id.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
}

function node<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className: string,
): HTMLElementTagNameMap[K] {
  const element = document.createElement(tag);
  element.className = className;
  return element;
}
