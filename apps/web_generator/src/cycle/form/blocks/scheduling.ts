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
  const instructions = node("p", "schedule-order__instructions");
  instructions.id = `${safeId(field.id)}-instructions`;
  instructions.textContent = locale.toLowerCase().startsWith("fr")
    ? "Faites glisser les séances pour les réordonner. Les flèches restent disponibles au clavier."
    : "Drag sessions to reorder them. Arrow buttons remain available from the keyboard.";
  const list = node("ol", "schedule-order__tokens");
  list.setAttribute("aria-describedby", instructions.id);
  const values = Array.isArray(field.value) ? [...field.value] : [];
  const isFrench = locale.toLowerCase().startsWith("fr");
  const reorder = (source: number, destination: number): void => {
    if (
      source === destination ||
      source < 0 ||
      destination < 0 ||
      source >= values.length ||
      destination >= values.length
    ) return;
    const reordered = [...values];
    const [moved] = reordered.splice(source, 1);
    if (moved === undefined) return;
    reordered.splice(destination, 0, moved);
    emit(dispatch, schemaId, field, reordered);
  };
  let pointerDrag: {
    readonly pointerId: number;
    readonly source: number;
    destination: number;
    readonly sourceItem: HTMLElement;
  } | undefined;
  const clearPointerTarget = (): void => {
    list.querySelectorAll(".is-drag-over").forEach((entry) =>
      entry.classList.remove("is-drag-over"));
  };
  const itemFromPointer = (event: PointerEvent): HTMLElement | undefined => {
    const candidates: Array<Element | null> = [];
    if (typeof document.elementFromPoint === "function") {
      candidates.push(document.elementFromPoint(event.clientX, event.clientY));
    }
    candidates.push(event.target instanceof Element ? event.target : null);
    for (const candidate of candidates) {
      const item = candidate?.closest<HTMLElement>(".schedule-order__item");
      if (item?.parentElement === list) return item;
    }
    return undefined;
  };
  const updatePointerTarget = (event: PointerEvent): void => {
    if (!pointerDrag) return;
    const item = itemFromPointer(event);
    const destination = Number(item?.dataset.orderIndex);
    clearPointerTarget();
    if (!item || !Number.isInteger(destination)) {
      pointerDrag.destination = pointerDrag.source;
      return;
    }
    pointerDrag.destination = destination;
    if (destination !== pointerDrag.source) item.classList.add("is-drag-over");
  };
  const onPointerMove = (event: PointerEvent): void => {
    if (!pointerDrag || event.pointerId !== pointerDrag.pointerId) return;
    event.preventDefault();
    updatePointerTarget(event);
  };
  const cleanupPointerDrag = (): void => {
    if (!pointerDrag) return;
    pointerDrag.sourceItem.classList.remove("is-dragging");
    clearPointerTarget();
    pointerDrag = undefined;
    document.removeEventListener("pointermove", onPointerMove);
    document.removeEventListener("pointerup", onPointerUp);
    document.removeEventListener("pointercancel", onPointerCancel);
  };
  const onPointerUp = (event: PointerEvent): void => {
    if (!pointerDrag || event.pointerId !== pointerDrag.pointerId) return;
    event.preventDefault();
    updatePointerTarget(event);
    const { source, destination } = pointerDrag;
    cleanupPointerDrag();
    reorder(source, destination);
  };
  const onPointerCancel = (event: PointerEvent): void => {
    if (!pointerDrag || event.pointerId !== pointerDrag.pointerId) return;
    cleanupPointerDrag();
  };
  const startPointerDrag = (
    event: PointerEvent,
    source: number,
    sourceItem: HTMLElement,
  ): void => {
    if (
      !enabled ||
      pointerDrag ||
      event.pointerType === "mouse" ||
      event.button !== 0 ||
      (event.target instanceof Element && event.target.closest("button"))
    ) return;
    event.preventDefault();
    pointerDrag = {
      pointerId: event.pointerId,
      source,
      destination: source,
      sourceItem,
    };
    sourceItem.classList.add("is-dragging");
    document.addEventListener("pointermove", onPointerMove, { passive: false });
    document.addEventListener("pointerup", onPointerUp);
    document.addEventListener("pointercancel", onPointerCancel);
  };
  values.forEach((value, index) => {
    const choice = field.choices?.find((item) => serialized(item.value) === serialized(value));
    const item = node("li", "schedule-order__item");
    const itemLabel = choice ? localized(choice.label, locale) : "—";
    item.draggable = enabled;
    item.style.touchAction = enabled ? "none" : "auto";
    item.dataset.orderIndex = String(index);
    item.setAttribute(
      "aria-label",
      isFrench ? `${itemLabel}, position ${index + 1}` : `${itemLabel}, position ${index + 1}`,
    );
    const handle = node("span", "schedule-token__handle");
    handle.textContent = "⋮⋮";
    handle.setAttribute("aria-hidden", "true");
    const label = node("span", "schedule-token");
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
        reorder(index, destination);
      });
      return button;
    };
    item.addEventListener("dragstart", (event) => {
      if (!enabled || !event.dataTransfer) {
        event.preventDefault();
        return;
      }
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("text/plain", String(index));
      item.classList.add("is-dragging");
    });
    item.addEventListener("dragend", () => {
      item.classList.remove("is-dragging");
      list.querySelectorAll(".is-drag-over").forEach((entry) =>
        entry.classList.remove("is-drag-over"));
    });
    item.addEventListener("dragover", (event) => {
      if (!enabled) return;
      event.preventDefault();
      if (event.dataTransfer) event.dataTransfer.dropEffect = "move";
      item.classList.add("is-drag-over");
    });
    item.addEventListener("dragleave", () => item.classList.remove("is-drag-over"));
    item.addEventListener("drop", (event) => {
      event.preventDefault();
      item.classList.remove("is-drag-over");
      const source = Number(event.dataTransfer?.getData("text/plain"));
      if (Number.isInteger(source)) reorder(source, index);
    });
    item.addEventListener("pointerdown", (event) => {
      startPointerDrag(event, index, item);
    });
    controls.append(moveButton(-1), moveButton(1));
    item.append(handle, label, controls);
    list.append(item);
  });
  group.append(legend, instructions, list);
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
