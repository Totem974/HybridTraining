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

interface RenderContext {
  readonly options: ProgramRenderOptions;
  readonly dateFormatter: Intl.DateTimeFormat;
  readonly weightFormatter: Intl.NumberFormat;
}

export function renderProgram(
  target: HTMLElement,
  response: CycleResponseLike,
  options: ProgramRenderOptions,
): void {
  // Formatters are deliberately shared across the complete render. Constructing
  // one per set is expensive on larger cycles.
  const context: RenderContext = {
    options,
    dateFormatter: new Intl.DateTimeFormat(options.labels.dateLocale, {
      day: "numeric",
      month: "short",
    }),
    weightFormatter: new Intl.NumberFormat(options.labels.dateLocale, {
      maximumFractionDigits: 2,
    }),
  };
  const fragment = document.createDocumentFragment();
  for (const week of response.weeks) fragment.append(renderWeek(week, context));
  target.replaceChildren(fragment);
}

function renderWeek(week: WeekLike, context: RenderContext): HTMLElement {
  const section = element("section", "program-week");
  const title = element(
    "h3",
    "program-week__title",
    `${context.options.labels.week} ${week.number}`,
  );
  title.id = `program-week-${week.number}`;
  section.setAttribute("aria-labelledby", title.id);
  section.append(title);

  const grid = element("div", "session-grid");
  grid.setAttribute("role", "list");
  const sessions = document.createDocumentFragment();
  for (const session of week.sessions) sessions.append(renderSession(session, context));
  grid.append(sessions);
  section.append(grid);
  return section;
}

function renderSession(session: SessionLike, context: RenderContext): HTMLElement {
  const card = element("article", "session-card");
  card.setAttribute("role", "listitem");
  const name = displayMovement(
    session.movementId,
    context.options.labels.movementNames,
    context.options.labels.session,
  );
  card.setAttribute("aria-label", name);

  const header = element("header", "session-card__header");
  header.append(element("h4", "session-card__title", name));
  if (session.date) {
    const date = new Date(session.date);
    if (!Number.isNaN(date.valueOf())) {
      const time = element(
        "time",
        "session-card__date",
        context.dateFormatter.format(date),
      );
      time.dateTime = session.date;
      header.append(time);
    }
  }
  card.append(header);

  const blocks = document.createDocumentFragment();
  for (const block of session.blocks) blocks.append(renderBlock(block, context));
  card.append(blocks);
  return card;
}

function renderBlock(block: BlockLike, context: RenderContext): HTMLElement {
  const group = element("section", "session-block");
  const blockName = displayName(
    block.role,
    context.options.labels.blockNames ?? {},
    context.options.labels.block,
  );
  group.append(element("h5", "session-block__title", blockName));

  if (block.movementId) {
    const movementName = displayMovement(
      block.movementId,
      context.options.labels.movementNames,
      "",
    );
    if (movementName) group.append(element("p", "session-block__movement", movementName));
  }

  const list = element("ol", "set-list");
  for (const set of block.sets) list.append(renderSet(set, context));
  group.append(list);
  return group;
}

function renderSet(set: SetLike, context: RenderContext): HTMLLIElement {
  const row = element("li", "set-row");
  row.append(
    element(
      "span",
      "set-row__prescription",
      formatSet(set, context.weightFormatter),
    ),
  );
  if (context.options.showPlating && set.platesPerSide?.length) {
    const plates = element("span", "set-row__plates");
    const labels = set.platesPerSide.map((plate) =>
      formatWeight(plate, context.weightFormatter)
    );
    plates.setAttribute("aria-label", labels.join(", "));
    for (const label of labels) {
      const chip = element("span", "plate-chip", label);
      chip.dataset.plate = "";
      chip.setAttribute("aria-hidden", "true");
      plates.append(chip);
    }
    row.append(plates);
  }
  return row;
}

function formatSet(set: SetLike, weightFormatter: Intl.NumberFormat): string {
  const repetitions = set.repetitions;
  let reps = "—";
  if (typeof repetitions.count === "number") reps = String(repetitions.count);
  else if (typeof repetitions.total === "number") reps = String(repetitions.total);
  else if (
    typeof repetitions.minimum === "number" &&
    typeof repetitions.maximum === "number"
  ) {
    reps = `${repetitions.minimum}–${repetitions.maximum}`;
  } else if (repetitions.type === "amrap") {
    reps = "AMRAP";
  }
  const load = set.plannedLoad
    ? formatWeight(set.plannedLoad, weightFormatter)
    : "—";
  return `${reps} × ${load}`;
}

function formatWeight(weight: WeightLike, formatter: Intl.NumberFormat): string {
  return `${formatter.format(weight.centiUnits / 100)} ${weight.unit}`;
}

function displayName(
  id: string,
  names: Readonly<Record<string, string>>,
  fallback: string,
): string {
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
