import { renderCycleForm, localized, type CycleEditorSchema, type CycleFormIntent, type JsonValue } from './cycle/form';
import { renderProgram, type CycleResponseLike } from './cycle/program';
import { EngineClient } from './engine';
import { PreferencesStore, type Locale } from './storage/preferences';

interface CatalogIndex {
  readonly templates: readonly {
    readonly id: string;
    readonly labels: Readonly<Record<string, string>>;
    readonly variantIds: readonly string[];
  }[];
}

const root = document.documentElement;
const status = document.querySelector<HTMLElement>('[data-cycle-mount="status"], #engine-status');
const program = document.querySelector<HTMLElement>('[data-cycle-mount="program"]');
const preferences = new PreferencesStore();
let locale: Locale = preferences.read().locale;
let client: EngineClient;
let catalog: CatalogIndex;
let schema: CycleEditorSchema;
let values: Record<string, JsonValue> = {};
let disposeForm: (() => void) | undefined;

async function start(): Promise<void> {
  try {
    client = await EngineClient.initialize();
    catalog = client.catalogIndex<CatalogIndex>({ apiVersion: 'v1', schemaVersion: 1 });
    const preferred = catalog.templates.find((item) => item.id === 'classic_531') ?? catalog.templates[0];
    if (!preferred?.variantIds[0]) throw new Error('CATALOG_HAS_NO_CYCLE_VARIANTS');
    await loadSchema(preferred.id, preferred.variantIds[0], false);
    installLocaleControls();
    root.dataset.cycleReady = 'true';
    if (status) status.textContent = '';
  } catch (error) {
    root.dataset.cycleReady = 'false';
    if (status) status.textContent = message(error);
  }
}

async function loadSchema(templateId: string, variantId: string, preserve: boolean): Promise<void> {
  const next = client.cycleEditorSchema<CycleEditorSchema>({
    apiVersion: 'v1',
    schemaVersion: 1,
    templateId,
    variantId,
  });
  const previous = preserve ? values : {};
  schema = {
    ...next,
    fields: next.fields.map((field) => ({
      ...field,
      value: field.path === 'showPlating'
        ? preferences.read().showPlating
        : ['templateId', 'variantId', 'sessionOrder'].includes(field.path)
          ? field.value
          : previous[field.path] ?? field.value,
    })),
  };
  values = Object.fromEntries(schema.fields.map((field) => [field.path, field.value]));
  renderEditor();
}

function renderEditor(): void {
  disposeForm?.();
  root.lang = locale;
  disposeForm = renderCycleForm({
    schema,
    root: document,
    locale,
    dispatch: handleIntent,
  });
}

async function handleIntent(intent: CycleFormIntent): Promise<void> {
  if (intent.type === 'cycle.action.requested') {
    if (intent.action === 'generate') generate();
    return;
  }
  if (!intent.path || intent.value === undefined) return;
  values[intent.path] = intent.value;
  if (intent.path === 'templateId' && typeof intent.value === 'string') {
    const selected = catalog.templates.find((item) => item.id === intent.value);
    if (selected?.variantIds[0]) await loadSchema(selected.id, selected.variantIds[0], true);
    return;
  }
  if (intent.path === 'variantId' && typeof intent.value === 'string') {
    await loadSchema(String(values.templateId), intent.value, true);
    return;
  }
  schema = {
    ...schema,
    fields: schema.fields.map((field) => field.path === intent.path ? { ...field, value: intent.value! } : field),
  };
  if (intent.path === 'showPlating' && typeof intent.value === 'boolean') {
    preferences.setShowPlating(intent.value);
  }
  if (schema.fields.some((field) =>
    [...(field.visibleWhen ?? []), ...(field.enabledWhen ?? [])]
      .some((condition) => condition.path === intent.path)
  )) {
    renderEditor();
  }
}

function generate(): void {
  try {
    const request = buildCycleRequest();
    const cycle = client.generateCycle<CycleResponseLike>(request);
    if (!program) throw new Error('PROGRAM_MOUNT_MISSING');
    renderProgram(program, cycle, {
      showPlating: Boolean(values.showPlating),
      labels: {
        week: locale === 'fr' ? 'SEMAINE' : 'WEEK',
        session: locale === 'fr' ? 'Séance' : 'Session',
        block: locale === 'fr' ? 'Bloc' : 'Block',
        dateLocale: locale,
        movementNames: movementNames(),
        blockNames: {
          warm_up: locale === 'fr' ? 'Échauffement' : 'Warm-up',
          main_work: locale === 'fr' ? 'Travail principal' : 'Main work',
          supplemental: locale === 'fr' ? 'Supplémentaire' : 'Supplemental',
          assistance: 'Assistance',
          deload: 'Deload',
        },
      },
    });
    if (status) status.textContent = locale === 'fr' ? 'Programme généré.' : 'Program generated.';
  } catch (error) {
    if (status) status.textContent = message(error);
  }
}

function buildCycleRequest(): object {
  const unit = values.unit === 'lb' ? 'lb' : 'kg';
  const order = Array.isArray(values.sessionOrder)
    ? values.sessionOrder.filter((item): item is string => typeof item === 'string')
    : [];
  if (order.length === 0) throw new Error('SESSION_ORDER_REQUIRED');
  const mode = typeof values.maxMode === 'string' ? values.maxMode : 'oneRepMax';
  const movements = schema.fields
    .filter((field) => field.id.startsWith('max-load-'))
    .map((field) => field.id.slice('max-load-'.length));
  const requestMovements = [...new Set([...movements, ...order])];
  const maxInputs = Object.fromEntries(requestMovements.map((movement) => {
    const weight = numberValue(`maxInputs.${movement}.weight`, 100);
    const input: Record<string, unknown> = {
      type: mode,
      weight: { centiUnits: Math.round(weight * 100), unit },
    };
    if (mode === 'repMax') {
      input.repetitions = Math.round(numberValue(`maxInputs.${movement}.repetitions`, 5));
      input.formula = 'epley';
    }
    return [movement, input];
  }));
  const platesPerSide = Object.entries(values)
    .filter(([path, count]) => path.startsWith('plates.') && typeof count === 'number' && count > 0)
    .flatMap(([path, count]) => Array.from({ length: Math.round(count as number) }, () => ({
      centiUnits: Math.round(Number(path.slice('plates.'.length)) * 100), unit,
    })));
  const smallest = Math.min(...platesPerSide.map((plate) => plate.centiUnits));
  const percentageParameters = Object.fromEntries(
    schema.fields
      .filter((field) => field.path.startsWith('options.') && field.kind === 'percentage')
      .map((field) => [field.path.slice('options.'.length), Math.round(numberValue(field.path, Number(field.value ?? 0)))]),
  );
  return {
    apiVersion: 'v1', schemaVersion: 1,
    cycleId: `cycle-${Date.now()}`,
    templateId: String(values.templateId), variantId: String(values.variantId),
    startDate: `${String(values.startDate)}T00:00:00.000`,
    trainingDays: order.map((_, index) => index + 1), sessionOrder: order,
    maxInputs,
    globalTrainingMaxRatioBasisPoints: Math.round(numberValue('globalTrainingMaxRatioBasisPoints', 9000)),
    trainingMaxRatioByMovement: {}, percentageParameters, percentageParametersByMovement: {},
    options: Object.fromEntries(Object.entries(values).filter(([path]) => path.startsWith('options.'))),
    unit,
    roundingIncrement: { centiUnits: Number.isFinite(smallest) ? smallest * 2 : 250, unit },
    barProfile: {
      weight: { centiUnits: Math.round(numberValue('barWeight', 20) * 100), unit },
      platesPerSide,
    },
    includeDeload: values['options.include_deload'] !== false,
    programTitle: String(values.programTitle ?? '5/3/1'),
    showPlating: Boolean(values.showPlating),
  };
}

function movementNames(): Record<string, string> {
  return Object.fromEntries(schema.fields
    .filter((field) => field.id.startsWith('max-load-'))
    .map((field) => [field.id.slice('max-load-'.length), localized(field.label, locale)]));
}

function numberValue(path: string, fallback: number): number {
  const value = values[path];
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function installLocaleControls(): void {
  const header = document.querySelector('.site-header');
  if (!header || header.querySelector('[data-locale-controls]')) return;
  const controls = document.createElement('div');
  controls.dataset.localeControls = '';
  controls.className = 'segmented-control';
  for (const candidate of ['fr', 'en'] as const) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = candidate === 'fr' ? 'Français' : 'English';
    button.ariaPressed = String(locale === candidate);
    button.addEventListener('click', () => {
      locale = candidate;
      preferences.setLocale(candidate);
      controls.querySelectorAll('button').forEach((item) => item.ariaPressed = String(item === button));
      renderEditor();
    });
    controls.append(button);
  }
  header.append(controls);
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : 'INITIALIZATION_FAILED';
}

void start();
