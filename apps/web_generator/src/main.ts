import { renderCycleForm, localized, type CycleEditorSchema, type CycleFormIntent, type JsonValue } from './cycle/form';
import { renderProgram, type CycleResponseLike } from './cycle/program';
import { buildCycleRequest } from './cycle/request/buildCycleRequest';
import { changeEditorValue, normalizeEditorState } from './cycle/state/editorState';
import {
  currentDraftId,
  cycleDraft,
  draftEnvelope,
  restoreCompatibleDraft,
  type CycleDraftPayload,
} from './cycle/storage/cyclePersistence';
import { EngineClient } from './engine';
import {
  exportConfiguration,
  exportProgram,
  IndexedDbWorkspaceStorage,
  importValidatedArtifact,
  SavedConfigurationRepository,
  TrainingSnapshotRepository,
  WorkspaceDraftRepository,
  type LocalArtifact,
} from './storage';
import { PreferencesStore, type Locale } from './storage/preferences';
import type { CycleResponse, ValidationReport } from '../../../contracts/v1/generated/contracts';

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
let defaultValues: Record<string, JsonValue> = {};
let disposeForm: (() => void) | undefined;
let lastRequest: object | undefined;
let lastResponse: CycleResponse | undefined;
let generationTimer: ReturnType<typeof setTimeout> | undefined;
let workspaceStorage: IndexedDbWorkspaceStorage | undefined;
let drafts: WorkspaceDraftRepository<CycleDraftPayload> | undefined;
let configurations: SavedConfigurationRepository<object> | undefined;
let snapshots: TrainingSnapshotRepository<object> | undefined;

const translations = {
  en: { eyebrow: 'Training tools', pageTitle: 'Cycle generator', pageSummary: 'Configure and generate a training cycle locally in your browser.', weight: 'Weight', template: 'Template', additionalOptions: 'Additional options', plating: 'Plating & barbell', scheduling: 'Scheduling', output: 'Output', program: 'Program' },
  fr: { eyebrow: 'Outils d’entraînement', pageTitle: 'Générateur de cycle', pageSummary: 'Configurez votre cycle localement dans votre navigateur.', weight: 'Charges', template: 'Modèle', additionalOptions: 'Options supplémentaires', plating: 'Plaques et barre', scheduling: 'Planification', output: 'Sortie', program: 'Programme' },
} as const;

async function start(): Promise<void> {
  try {
    client = await EngineClient.initialize();
    catalog = client.catalogIndex<CatalogIndex>({ apiVersion: 'v1', schemaVersion: 1 });
    installRepositories();
    const allowed = new Map(catalog.templates.map((template) => [
      template.id,
      new Set(template.variantIds),
    ]));
    const restored = drafts
      ? await restoreCompatibleDraft(drafts, client.contractMetadata(), allowed)
      : undefined;
    const preferred = restored
      ? catalog.templates.find((item) => item.id === restored.templateId)
      : catalog.templates[0];
    const preferredVariant = restored?.variantId ?? preferred?.variantIds[0];
    if (!preferred || !preferredVariant) throw new Error('CATALOG_HAS_NO_CYCLE_VARIANTS');
    await loadSchema(
      preferred.id,
      preferredVariant,
      restored?.values,
      restored?.scheduleId,
    );
    installLocaleControls();
    root.dataset.cycleReady = 'true';
    if (status) status.textContent = '';
  } catch (error) {
    root.dataset.cycleReady = 'false';
    if (status) status.textContent = message(error);
  }
}

async function loadSchema(
  templateId: string,
  variantId: string,
  candidates: Readonly<Record<string, JsonValue>> = {},
  scheduleId?: string,
): Promise<void> {
  const next = client.cycleEditorSchema<CycleEditorSchema>({
    apiVersion: 'v1',
    schemaVersion: 1,
    templateId,
    variantId,
    ...(scheduleId ? { scheduleId } : {}),
  });
  const merged = {
    ...candidates,
    showPlating: preferences.read().showPlating,
  };
  const normalized = normalizeEditorState(next, merged, new Set([
    'templateId',
    'variantId',
    'scheduleId',
    'sessionOrder',
  ]));
  schema = normalized.schema;
  values = normalized.values;
  defaultValues = normalized.defaults;
  renderEditor();
  persistDraft();
  scheduleGeneration();
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
  applyStaticTranslations();
  installTransferControls();
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
    if (selected?.variantIds[0]) await loadSchema(selected.id, selected.variantIds[0], values);
    return;
  }
  if (intent.path === 'variantId' && typeof intent.value === 'string') {
    await loadSchema(String(values.templateId), intent.value, values);
    return;
  }
  if (intent.path === 'scheduleId' && typeof intent.value === 'string') {
    await loadSchema(String(values.templateId), String(values.variantId), values, intent.value);
    return;
  }
  const normalized = changeEditorValue(
    { schema, values, defaults: defaultValues },
    intent.path,
    intent.value,
  );
  schema = normalized.schema;
  values = normalized.values;
  defaultValues = normalized.defaults;
  if (intent.path === 'showPlating' && typeof intent.value === 'boolean') {
    preferences.setShowPlating(intent.value);
  }
  renderEditor();
  persistDraft();
  scheduleGeneration();
}

function scheduleGeneration(): void {
  if (generationTimer) clearTimeout(generationTimer);
  generationTimer = setTimeout(() => generate(), 80);
}

function generate(): void {
  generateRequest(buildCycleRequest(schema, values));
}

function generateRequest(request: object): void {
  try {
    const response = client.generateCycle<CycleResponse>(request);
    lastRequest = request;
    lastResponse = response;
    persistGeneration(request, response);
    if (!program) throw new Error('PROGRAM_MOUNT_MISSING');
    renderProgram(program, response.cycle as CycleResponseLike, {
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

function installTransferControls(): void {
  const mount = document.querySelector<HTMLElement>('[data-cycle-mount="output"]');
  if (!mount || mount.querySelector('[data-transfer-controls]')) return;
  const controls = document.createElement('div');
  controls.className = 'transfer-actions';
  controls.dataset.transferControls = '';
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'application/json,.json';
  input.className = 'visually-hidden';
  input.addEventListener('change', async () => {
    const file = input.files?.[0];
    if (!file) return;
    try {
      const imported = await importValidatedArtifact(
        await file.text(),
        'configuration',
        (candidate) => metadataMatchesCurrent(candidate)
          ? validateImportedRequest(candidate.payload as Record<string, unknown>)
          : ({ valid: false, errors: [{ code: 'VERSION_MISMATCH' }] }),
      );
      await hydrateImportedRequest(imported.payload as Record<string, unknown>);
    } catch (error) {
      if (status) status.textContent = message(error);
    } finally {
      input.value = '';
    }
  });
  controls.append(
    transferButton(locale === 'fr' ? 'Exporter la configuration' : 'Export configuration', () => {
      const request = buildCycleRequest(schema, values);
      download('cycle-configuration.json', exportConfiguration(artifact('configuration', request)));
    }),
    transferButton(locale === 'fr' ? 'Exporter le programme' : 'Export program', () => {
      if (!lastResponse) throw new Error('GENERATE_BEFORE_EXPORT');
      download('cycle-program.json', exportProgram(artifact('program', lastResponse)));
    }),
    transferButton(locale === 'fr' ? 'Importer' : 'Import', () => input.click()),
    input,
  );
  mount.append(controls);
}

function validateImportedRequest(request: Record<string, unknown>): ValidationReport {
  try {
    const schemaRequest = {
      apiVersion: 'v1',
      schemaVersion: 1,
      templateId: typeof request.templateId === 'string' ? request.templateId : '',
      variantId: typeof request.variantId === 'string' ? request.variantId : '',
      ...(typeof request.scheduleId === 'string' ? { scheduleId: request.scheduleId } : {}),
    };
    let importedSchema: CycleEditorSchema;
    try {
      importedSchema = client.cycleEditorSchema<CycleEditorSchema>(schemaRequest);
    } catch {
      const { scheduleId: _, ...withoutStaleSchedule } = schemaRequest;
      importedSchema = client.cycleEditorSchema<CycleEditorSchema>(withoutStaleSchedule);
    }
    const importedState = normalizeEditorState(importedSchema, requestValues(request), new Set([
      'templateId',
      'variantId',
      'scheduleId',
      'sessionOrder',
    ]));
    const cycleId = typeof request.cycleId === 'string' ? request.cycleId : undefined;
    return client.validateCycle<ValidationReport>(
      buildCycleRequest(importedState.schema, importedState.values, cycleId ? { cycleId } : {}),
    );
  } catch {
    return {
      ...client.contractMetadata(),
      valid: false,
      errors: [{
        code: 'INVALID_IMPORTED_REQUEST',
        path: '',
        messageKey: 'engine.invalidCycleRequest',
        details: {},
        severity: 'error',
      }],
      warnings: [],
    };
  }
}

function transferButton(label: string, action: () => void): HTMLButtonElement {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'secondary-action';
  button.textContent = label;
  button.addEventListener('click', () => {
    try { action(); } catch (error) { if (status) status.textContent = message(error); }
  });
  return button;
}

function artifact<T>(artifactKind: 'configuration' | 'program', payload: T): LocalArtifact<T> {
  return { ...client.contractMetadata(), artifactKind, payload };
}

function download(fileName: string, content: string): void {
  const url = URL.createObjectURL(new Blob([content], { type: 'application/json' }));
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

function movementNames(): Record<string, string> {
  return Object.fromEntries(schema.fields
    .filter((field) => field.id.startsWith('max-load-'))
    .map((field) => [field.id.slice('max-load-'.length), localized(field.label, locale)]));
}

function installRepositories(): void {
  try {
    workspaceStorage = new IndexedDbWorkspaceStorage();
    drafts = new WorkspaceDraftRepository(workspaceStorage);
    configurations = new SavedConfigurationRepository(workspaceStorage);
    snapshots = new TrainingSnapshotRepository(workspaceStorage);
  } catch {
    workspaceStorage = undefined;
  }
}

function persistDraft(): void {
  if (!drafts || !client || !schema) return;
  void drafts.save(
    currentDraftId,
    draftEnvelope(client.contractMetadata(), cycleDraft(values)),
  ).catch(() => undefined);
}

function persistGeneration(request: object, response: CycleResponse): void {
  if (configurations) {
    void configurations.save(
      'cycle-latest',
      artifact('configuration', request),
    ).catch(() => undefined);
  }
  if (snapshots) {
    void snapshots.save(
      response.snapshot.logicalHash,
      response.snapshot,
    ).catch(() => undefined);
  }
}

function metadataMatchesCurrent(candidate: LocalArtifact): boolean {
  const metadata = client.contractMetadata();
  return candidate.apiVersion === metadata.apiVersion &&
    candidate.schemaVersion === metadata.schemaVersion &&
    candidate.engineVersion === metadata.engineVersion &&
    candidate.catalogVersion === metadata.catalogVersion &&
    candidate.catalogHash === metadata.catalogHash;
}

async function hydrateImportedRequest(request: Record<string, unknown>): Promise<void> {
  const templateId = typeof request.templateId === 'string' ? request.templateId : '';
  const variantId = typeof request.variantId === 'string' ? request.variantId : '';
  const scheduleId = typeof request.scheduleId === 'string' ? request.scheduleId : undefined;
  const importedValues = requestValues(request);
  try {
    await loadSchema(templateId, variantId, importedValues, scheduleId);
  } catch {
    await loadSchema(templateId, variantId, importedValues);
  }
  if (generationTimer) clearTimeout(generationTimer);
  const cycleId = typeof request.cycleId === 'string' ? request.cycleId : undefined;
  generateRequest(buildCycleRequest(schema, values, cycleId ? { cycleId } : {}));
}

function requestValues(request: Record<string, unknown>): Record<string, JsonValue> {
  const result: Record<string, JsonValue> = {};
  for (const key of ['templateId', 'variantId', 'scheduleId', 'sessionOrder', 'unit', 'programTitle', 'showPlating']) {
    if (request[key] !== undefined) result[key] = request[key];
  }
  if (typeof request.startDate === 'string') result.startDate = request.startDate.slice(0, 10);
  if (typeof request.globalTrainingMaxRatioBasisPoints === 'number') {
    result.globalTrainingMaxRatioBasisPoints = request.globalTrainingMaxRatioBasisPoints;
  }
  const maxInputs = record(request.maxInputs);
  for (const [movement, rawInput] of Object.entries(maxInputs)) {
    const input = record(rawInput);
    if (typeof input.type === 'string') result.maxMode = input.type;
    const inputWeight = record(input.weight);
    if (typeof inputWeight.centiUnits === 'number') {
      result[`maxInputs.${movement}.weight`] = inputWeight.centiUnits / 100;
    }
    if (typeof input.repetitions === 'number') {
      result[`maxInputs.${movement}.repetitions`] = input.repetitions;
    }
  }
  const optionValues = record(request.options);
  flattenOptionValues(optionValues, 'options', result);
  for (const [id, value] of Object.entries(record(request.percentageParameters))) {
    result[`options.${id}`] = value;
  }
  const barProfile = record(request.barProfile);
  const barWeight = record(barProfile.weight);
  if (typeof barWeight.centiUnits === 'number') result.barWeight = barWeight.centiUnits / 100;
  const plateCounts = new Map<number, number>();
  if (Array.isArray(barProfile.platesPerSide)) {
    for (const rawPlate of barProfile.platesPerSide) {
      const plate = record(rawPlate);
      if (typeof plate.centiUnits !== 'number') continue;
      const denomination = plate.centiUnits / 100;
      plateCounts.set(denomination, (plateCounts.get(denomination) ?? 0) + 1);
    }
  }
  for (const [denomination, count] of plateCounts) result[`plates.${denomination}`] = count;
  return result;
}

function flattenOptionValues(
  source: Record<string, JsonValue>,
  prefix: string,
  target: Record<string, JsonValue>,
): void {
  for (const [key, value] of Object.entries(source)) {
    const path = `${prefix}.${key}`;
    if (isPlainRecord(value) && !isWeightValue(value)) {
      flattenOptionValues(value, path, target);
    } else {
      target[path] = isPlainRecord(value) && isWeightValue(value)
        ? value.centiUnits / 100
        : structuredClone(value);
    }
  }
}

function isPlainRecord(value: unknown): value is Record<string, JsonValue> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isWeightValue(
  value: Record<string, JsonValue>,
): value is Record<string, JsonValue> & { centiUnits: number; unit: 'kg' | 'lb' } {
  return typeof value.centiUnits === 'number' && (value.unit === 'kg' || value.unit === 'lb');
}

function record(value: unknown): Record<string, JsonValue> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, JsonValue>
    : {};
}

function installLocaleControls(): void {
  const controls = document.querySelector<HTMLElement>('[data-locale-controls]');
  if (!controls || controls.childElementCount > 0) return;
  for (const candidate of ['fr', 'en'] as const) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = candidate.toUpperCase();
    button.ariaPressed = String(locale === candidate);
    button.addEventListener('click', () => {
      locale = candidate;
      preferences.setLocale(candidate);
      controls.querySelectorAll('button').forEach((item) => item.ariaPressed = String(item === button));
      renderEditor();
      scheduleGeneration();
    });
    controls.append(button);
  }
}

function applyStaticTranslations(): void {
  const messages = translations[locale];
  document.querySelectorAll<HTMLElement>('[data-i18n]').forEach((node) => {
    const key = node.dataset.i18n as keyof typeof messages | undefined;
    if (key && messages[key]) node.textContent = messages[key];
  });
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : 'INITIALIZATION_FAILED';
}

void start();
