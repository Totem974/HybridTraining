import { fieldIsEnabled, localized } from "../schema";
import type { CycleBlockRenderer, CycleEditorField, JsonValue } from "../types";

const node = <K extends keyof HTMLElementTagNameMap>(tag: K, className?: string) => {
  const value = document.createElement(tag);
  if (className) value.className = className;
  return value;
};

const safeId = (value: string) => `cycle-output-${value.replace(/[^a-zA-Z0-9_-]/g, "-")}`;

export const renderOutputBlock: CycleBlockRenderer = (context) => {
  const fragment = document.createDocumentFragment();
  const layout = node("div", "output-layout");
  for (const field of context.fields) {
    // Generation is automatic. Other schema-supported actions (for example,
    // local export) remain visible without teaching the UI any business rule.
    if (
      field.kind === "action" &&
      (field.id === "generate" || field.action?.toLowerCase().includes("generate"))
    ) continue;
    const enabled = fieldIsEnabled(field, context.values);
    if (field.kind === "boolean") layout.append(renderToggle(field, enabled));
    else if (field.kind === "action") layout.append(renderAction(field, enabled));
    else if (field.kind === "text") layout.append(renderText(field, enabled));
  }
  fragment.append(layout);
  return fragment;

  function dispatch(field: CycleEditorField, value: JsonValue): void {
    void context.dispatch({
      type: "cycle.field.changed",
      schemaId: context.schemaId,
      fieldId: field.id,
      path: field.path,
      value,
    });
  }

  function renderText(field: CycleEditorField, enabled: boolean): HTMLElement {
    const wrapper = node("div", "output-title");
    const label = node("label");
    const input = node("input");
    input.type = "text";
    input.id = safeId(field.id);
    input.name = field.path;
    input.value = typeof field.value === "string" ? field.value : "";
    input.disabled = !enabled;
    label.htmlFor = input.id;
    label.textContent = localized(field.label, context.locale);
    input.addEventListener("input", () => dispatch(field, input.value));
    wrapper.append(label, input);
    return wrapper;
  }

  function renderToggle(field: CycleEditorField, enabled: boolean): HTMLElement {
    const row = node("div", "output-option switch-row");
    const label = node("label");
    const input = node("input");
    input.type = "checkbox";
    input.id = safeId(field.id);
    input.name = field.path;
    input.checked = field.value === true;
    input.disabled = !enabled;
    label.htmlFor = input.id;
    label.textContent = localized(field.label, context.locale);
    input.addEventListener("change", () => dispatch(field, input.checked));
    row.append(label, input);
    return row;
  }

  function renderAction(field: CycleEditorField, enabled: boolean): HTMLElement {
    const button = node("button", "secondary-action output-action");
    button.type = "button";
    button.disabled = !enabled;
    button.textContent = localized(field.label, context.locale);
    button.addEventListener("click", () => {
      if (!field.action) return;
      void context.dispatch({
        type: "cycle.action.requested",
        schemaId: context.schemaId,
        fieldId: field.id,
        action: field.action,
      });
    });
    return button;
  }
};
