import { renderCycleForm, localized, type CycleEditorSchema, type CycleFormIntent, type JsonValue } from './cycle/form';
import { renderProgram, type CycleResponseLike } from './cycle/program';
import {
  cycleConfigurationToEditorValues,
  editorValuesToCycleConfiguration,
  migrateCycleRequestV1ToConfiguration,
} from './cycle/configuration';
import {
  createCycleShareUrl,
  readCycleConfigurationFromUrl,
} from './cycle/configuration/share';
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
import type { CycleConfiguration, CycleRequest, CycleResponse, ValidationReport } from '../../../contracts/v1/generated/contracts';

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
let currentConfiguration: CycleConfiguration;
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
    const fromUrl = readCycleConfigurationFromUrl();
    const restoredConfiguration = fromUrl ?? restored?.configuration;
    const preferred = restoredConfiguration
      ? catalog.templates.find((item) => item.id === restoredConfiguration.template.id)
      : catalog.templates[0];
    const preferredVariant = restoredConfiguration?.template.variantId ?? preferred?.variantIds[0];
    if (!preferred || !preferredVariant) throw new Error('CATALOG_HAS_NO_CYCLE_VARIANTS');
    await loadSchema(
      preferred.id,
      preferredVariant,
      restoredConfiguration,
      restoredConfiguration?.schedule.id,
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
  candidates: Readonly<Record<string, JsonValue>> | CycleConfiguration = {},
  scheduleId?: string,
): Promise<void> {
  const next = client.cycleEditorSchema<CycleEditorSchema>({
    apiVersion: 'v1',
    schemaVersion: 1,
    templateId,
    variantId,
    ...(scheduleId ? { scheduleId } : {}),
  });
  const candidateValues = isCycleConfiguration(candidates)
    ? cycleConfigurationToEditorValues(candidates, next)
    : candidates;
  const merged = {
    ...candidateValues,
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
  currentConfiguration = editorValuesToCycleConfiguration(
    schema,
    values,
    client.contractMetadata(),
  );
  updateShareUrl();
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
  currentConfiguration = editorValuesToCycleConfiguration(
    schema,
    values,
    client.contractMetadata(),
  );
  updateShareUrl();
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
  try {
    generateRequest(client.configurationToCycleRequest<CycleRequest>(currentConfiguration));
  } catch (error) {
    if (status) status.textContent = message(error);
  }
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
          ? validateImportedConfiguration(importConfiguration(candidate.payload))
          : ({ valid: false, errors: [{ code: 'VERSION_MISMATCH' }] }),
      );
      await hydrateImportedConfiguration(importConfiguration(imported.payload));
    } catch (error) {
      if (status) status.textContent = message(error);
    } finally {
      input.value = '';
    }
  });
  controls.append(
    transferButton(locale === 'fr' ? 'Exporter la configuration' : 'Export configuration', () => {
      download(
        'cycle-configuration.json',
        exportConfiguration(artifact('configuration', currentConfiguration)),
      );
    }),
    transferButton(locale === 'fr' ? 'Exporter le programme' : 'Export program', () => {
      if (!lastResponse) throw new Error('GENERATE_BEFORE_EXPORT');
      download('cycle-program.json', exportProgram(artifact('program', lastResponse)));
    }),
    transferButton(locale === 'fr' ? 'Copier le lien' : 'Copy share link', () => {
      const shareUrl = createCycleShareUrl(currentConfiguration);
      window.history.replaceState({}, '', shareUrl);
      void navigator.clipboard?.writeText(shareUrl.href).catch(() => undefined);
      if (status) status.textContent = locale === 'fr' ? 'Lien prêt à partager.' : 'Share link ready.';
    }),
    transferButton(locale === 'fr' ? 'Importer' : 'Import', () => input.click()),
    input,
  );
  mount.append(controls);
}

function validateImportedConfiguration(configuration: CycleConfiguration): ValidationReport {
  try {
    const schemaRequest = {
      apiVersion: 'v1',
      schemaVersion: 1,
      templateId: configuration.template.id,
      variantId: configuration.template.variantId,
      scheduleId: configuration.schedule.id,
    };
    let importedSchema: CycleEditorSchema;
    try {
      importedSchema = client.cycleEditorSchema<CycleEditorSchema>(schemaRequest);
    } catch {
      const { scheduleId: _, ...withoutStaleSchedule } = schemaRequest;
      importedSchema = client.cycleEditorSchema<CycleEditorSchema>(withoutStaleSchedule);
    }
    const importedState = normalizeEditorState(
      importedSchema,
      cycleConfigurationToEditorValues(configuration, importedSchema),
      new Set([
      'templateId',
      'variantId',
      'scheduleId',
      'sessionOrder',
      ]),
    );
    const normalizedConfiguration = editorValuesToCycleConfiguration(
      importedState.schema,
      importedState.values,
      client.contractMetadata(),
    );
    return client.validateCycle<ValidationReport>(
      client.configurationToCycleRequest<CycleRequest>(normalizedConfiguration),
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
    draftEnvelope(client.contractMetadata(), cycleDraft(currentConfiguration)),
  ).catch(() => undefined);
}

function persistGeneration(request: object, response: CycleResponse): void {
  if (configurations) {
    void configurations.save(
      'cycle-latest',
      artifact('configuration', currentConfiguration),
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

async function hydrateImportedConfiguration(configuration: CycleConfiguration): Promise<void> {
  const templateId = configuration.template.id;
  const variantId = configuration.template.variantId;
  const scheduleId = configuration.schedule.id;
  try {
    await loadSchema(templateId, variantId, configuration, scheduleId);
  } catch {
    await loadSchema(templateId, variantId, configuration);
  }
  if (generationTimer) clearTimeout(generationTimer);
  generateRequest(client.configurationToCycleRequest<CycleRequest>(currentConfiguration));
}

function importConfiguration(payload: unknown): CycleConfiguration {
  if (!isPlainRecord(payload)) throw new Error('INVALID_CONFIGURATION_PAYLOAD');
  if (payload.format === 'hybrid-training-cycle' && payload.configurationVersion === 1) {
    return structuredClone(payload) as unknown as CycleConfiguration;
  }
  if (payload.apiVersion === 'v1' && payload.schemaVersion === 1) {
    return migrateCycleRequestV1ToConfiguration(
      payload as unknown as CycleRequest,
      client.contractMetadata(),
    );
  }
  throw new Error('UNSUPPORTED_CONFIGURATION_VERSION');
}

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isCycleConfiguration(value: unknown): value is CycleConfiguration {
  return isPlainRecord(value) && value.format === 'hybrid-training-cycle' &&
    value.configurationVersion === 1;
}

function updateShareUrl(): void {
  if (!currentConfiguration) return;
  window.history.replaceState(
    {},
    '',
    createCycleShareUrl(currentConfiguration),
  );
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
