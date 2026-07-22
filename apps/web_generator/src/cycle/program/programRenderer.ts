export interface CycleResponseLike {
  readonly weeks: readonly WeekLike[];
}

interface WeekLike {
  readonly number: number;
  readonly sessions: readonly SessionLike[];
}

interface SessionLike {
  readonly date?: string;
  readonly movementId: string;
  readonly blocks: readonly BlockLike[];
}

interface BlockLike {
  readonly role: string;
  readonly movementId?: string;
  readonly sets: readonly SetLike[];
}

interface SetLike {
  readonly repetitions: Readonly<Record<string, unknown>>;
  readonly plannedLoad?: WeightLike | null;
  readonly platesPerSide?: readonly WeightLike[];
}

interface WeightLike {
  readonly centiUnits: number;
  readonly unit: "kg" | "lb";
}

export interface ProgramLabels {
  readonly week: string;
  readonly session: string;
  readonly block: string;
  readonly dateLocale: string;
  readonly movementNames: Readonly<Record<string, string>>;
  readonly blockNames?: Readonly<Record<string, string>>;
}

export interface ProgramRenderOptions {
  readonly labels: ProgramLabels;
  readonly showPlating: boolean;
}

export function renderProgram(
  target: HTMLElement,
  response: CycleResponseLike,
  options: ProgramRenderOptions,
): void {
  const fragment = document.createDocumentFragment();
  for (const week of response.weeks) fragment.append(renderWeek(week, options));
  target.replaceChildren(fragment);
}

function renderWeek(week: WeekLike, options: ProgramRenderOptions): HTMLElement {
  const section = element("section", "program-week");
  section.append(element("h3", "program-week__title", `${options.labels.week} ${week.number}`));
  const grid = element("div", "session-grid");
  for (const session of week.sessions) grid.append(renderSession(session, options));
  section.append(grid);
  return section;
}

function renderSession(session: SessionLike, options: ProgramRenderOptions): HTMLElement {
  const card = element("article", "session-card");
  const name = displayMovement(session.movementId, options.labels.movementNames, options.labels.session);
  card.setAttribute("aria-label", name);
  const header = element("header", "session-card__header");
  header.append(element("h4", "session-card__title", name));
  if (session.date) {
    const date = new Date(session.date);
    if (!Number.isNaN(date.valueOf())) {
      const time = element("time", "session-card__date", new Intl.DateTimeFormat(options.labels.dateLocale).format(date));
      time.dateTime = session.date;
      header.append(time);
    }
  }
  card.append(header);
  for (const block of session.blocks) card.append(renderBlock(block, options));
  return card;
}

function renderBlock(block: BlockLike, options: ProgramRenderOptions): HTMLElement {
  const group = element("section", "session-block");
  const blockName = displayName(block.role, options.labels.blockNames ?? {}, options.labels.block);
  group.append(element("h5", "session-block__title", blockName));
  if (block.movementId) {
    const movementName = displayMovement(block.movementId, options.labels.movementNames, "");
    if (movementName) group.append(element("p", "session-block__movement", movementName));
  }
  for (const set of block.sets) {
    const row = element("div", "set-row");
    row.append(element("span", "set-row__prescription", formatSet(set)));
    if (options.showPlating && set.platesPerSide?.length) {
      const plates = element("span", "set-row__plates");
      for (const plate of set.platesPerSide) {
        const chip = element("span", "plate-chip", formatWeight(plate));
        chip.dataset.plate = "";
        chip.setAttribute("aria-label", formatWeight(plate));
        plates.append(chip);
      }
      row.append(plates);
    }
    group.append(row);
  }
  return group;
}

function formatSet(set: SetLike): string {
  const repetitions = set.repetitions;
  let reps = "—";
  if (typeof repetitions.count === "number") reps = String(repetitions.count);
  else if (typeof repetitions.total === "number") reps = String(repetitions.total);
  else if (typeof repetitions.minimum === "number" && typeof repetitions.maximum === "number") {
    reps = `${repetitions.minimum}–${repetitions.maximum}`;
  } else if (repetitions.type === "amrap") reps = "AMRAP";
  return `${reps} × ${set.plannedLoad ? formatWeight(set.plannedLoad) : "—"}`;
}

function formatWeight(weight: WeightLike): string {
  return `${new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(weight.centiUnits / 100)} ${weight.unit}`;
}

function displayName(id: string, names: Readonly<Record<string, string>>, fallback: string): string {
  const label = names[id];
  return typeof label === "string" && label.trim() !== "" ? label : fallback;
}

function displayMovement(
  id: string,
  names: Readonly<Record<string, string>>,
  fallback: string,
): string {
  const direct = displayName(id, names, "");
  if (direct) return direct;
  const parts = id.split("+");
  if (parts.length > 1) {
    const labels = parts.map((part) => displayName(part, names, "")).filter(Boolean);
    if (labels.length === parts.length) return labels.join(" + ");
  }
  for (const left of Object.keys(names)) {
    for (const right of Object.keys(names)) {
      if (`${left}_${right}` === id) return `${names[left]} + ${names[right]}`;
    }
  }
  return fallback;
}

function element<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
