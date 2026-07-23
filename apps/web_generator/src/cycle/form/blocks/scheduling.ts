import { fieldIsEnabled, localized } from "../schema";
import type {
  CycleBlockRenderer,
  CycleEditorChoice,
  CycleEditorField,
  CycleFormIntentHandler,
  JsonValue,
} from "../types";

const node = <K extends keyof HTMLElementTagNameMap>(tag: K, className?: string) => {
  const value = document.createElement(tag);
  if (className) value.className = className;
  return value;
};

const safeId = (value: string) => `cycle-scheduling-${value.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
const serialized = (value: JsonValue) => JSON.stringify(value);

function emit(
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

function selectedChoice(field: CycleEditorField): CycleEditorChoice | undefined {
  return field.choices?.find((choice) => serialized(choice.value) === serialized(field.value));
}

function renderFrequency(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const group = node("fieldset", "schedule-frequency");
  const legend = node("legend");
  legend.textContent = localized(field.label, locale);
  group.append(legend);
  const choices = field.choices ?? [];
  if (field.readOnly || choices.length <= 1) {
    const value = node("output", "schedule-frequency__value");
    value.textContent = selectedChoice(field)
      ? localized(selectedChoice(field)!.label, locale)
      : "—";
    value.setAttribute("aria-live", "off");
    group.append(value);
    return group;
  }
  const segmented = node("div", "segmented-control schedule-frequency__choices");
  for (const choice of choices) {
    const label = node("label");
    const input = node("input");
    input.type = "radio";
    input.name = field.path;
    input.value = serialized(choice.value);
    input.checked = input.value === serialized(field.value);
    input.disabled = !enabled;
    input.addEventListener("change", () => {
      if (input.checked) emit(dispatch, schemaId, field, choice.value);
    });
    label.append(input, document.createTextNode(localized(choice.label, locale)));
    segmented.append(label);
  }
  group.append(segmented);
  return group;
}

function renderDate(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const wrapper = node("div", "schedule-date");
  const label = node("label");
  const input = node("input", "schedule-date__input");
  input.type = "date";
  input.id = safeId(field.id);
  input.name = field.path;
  input.value = typeof field.value === "string" ? field.value : "";
  input.disabled = !enabled;
  label.htmlFor = input.id;
  label.textContent = localized(field.label, locale);
  input.addEventListener("change", () => emit(dispatch, schemaId, field, input.value));
  wrapper.append(label, input);
  return wrapper;
}

function renderOrder(
  field: CycleEditorField,
  locale: string,
  enabled: boolean,
  schemaId: string,
  dispatch: CycleFormIntentHandler,
): HTMLElement {
  const group = node("fieldset", "schedule-order");
  const legend = node("legend");
  legend.textContent = localized(field.label, locale);
  const list = node("ol", "schedule-order__tokens");
  const values = Array.isArray(field.value) ? [...field.value] : [];
  const isFrench = locale.toLowerCase().startsWith("fr");
  values.forEach((value, index) => {
    const choice = field.choices?.find((item) => serialized(item.value) === serialized(value));
    const item = node("li", "schedule-order__item");
    const label = node("span", "schedule-token");
    const itemLabel = choice ? localized(choice.label, locale) : "—";
    label.textContent = itemLabel;
    const controls = node("span", "schedule-token__controls");
    const moveButton = (direction: -1 | 1) => {
      const button = node("button", "schedule-token__move");
      const destination = index + direction;
      const directionLabel = isFrench
        ? direction < 0 ? "vers la gauche" : "vers la droite"
        : direction < 0 ? "left" : "right";
      button.type = "button";
      button.textContent = direction < 0 ? "←" : "→";
      button.disabled = !enabled || destination < 0 || destination >= values.length;
      button.setAttribute(
        "aria-label",
        isFrench
          ? `Déplacer ${itemLabel} ${directionLabel}`
          : `Move ${itemLabel} ${directionLabel}`,
      );
      button.addEventListener("click", () => {
        if (button.disabled) return;
        [values[destination], values[index]] = [values[index], values[destination]];
        emit(dispatch, schemaId, field, values);
      });
      return button;
    };
    controls.append(moveButton(-1), moveButton(1));
    item.append(label, controls);
    list.append(item);
  });
  group.append(legend, list);
  return group;
}

export const renderSchedulingBlock: CycleBlockRenderer = (context) => {
  const fragment = document.createDocumentFragment();
  const layout = node("div", "scheduling-layout");
  for (const field of context.fields) {
    const enabled = fieldIsEnabled(field, context.values);
    if (field.kind === "date") {
      layout.append(renderDate(field, context.locale, enabled, context.schemaId, context.dispatch));
    } else if (field.kind === "token-order") {
      layout.append(renderOrder(field, context.locale, enabled, context.schemaId, context.dispatch));
    } else if (field.kind === "choice" || field.kind === "segmented") {
      layout.append(renderFrequency(field, context.locale, enabled, context.schemaId, context.dispatch));
    }
  }
  fragment.append(layout);
  return fragment;
};
