import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const fixturesRoot = resolve(process.argv[2] ?? 'test/fixtures/engine-v1');
const candidates = [
  process.env.TRAINING_ENGINE_BRIDGE,
  'packages/training_engine_web_bridge/build/engine_bridge.js',
  'packages/training_engine_web_bridge/build/training_engine_bridge.js',
  'apps/web_generator/public/engine/engine_bridge.js',
].filter(Boolean).map(resolve);
const artifact = candidates.find(existsSync);

if (!artifact) {
  console.log(JSON.stringify({
    status: 'skipped',
    reason: 'Bridge JavaScript artifact unavailable. Run engine:build or set TRAINING_ENGINE_BRIDGE; parity was not simulated.',
    searched: candidates,
  }));
  process.exit(2);
}

const catalogCandidates = [
  process.env.TRAINING_CATALOG_BUNDLE,
  'apps/web_generator/public/catalog.bundle.json',
  'build/catalog/catalog.bundle.json',
].filter(Boolean).map(resolve);
const catalog = catalogCandidates.find(existsSync);
if (!catalog) {
  console.log(JSON.stringify({
    status: 'skipped',
    reason: 'catalog.bundle.json unavailable; bridge parity was not simulated.',
    artifact,
    searched: catalogCandidates,
  }));
  process.exit(2);
}

try {
  const module = await import(pathToFileURL(artifact));
  const bridge = module.trainingEngineBridge ?? module.default ?? globalThis.trainingEngineBridge;
  if (!bridge || typeof bridge.initialize !== 'function' || typeof bridge.generateCycle !== 'function') {
    throw new Error('Artifact does not expose initialize(catalogJson) and generateCycle(requestJson).');
  }
  JSON.parse(await bridge.initialize(readFileSync(catalog, 'utf8')));
  const manifest = JSON.parse(readFileSync(resolve(fixturesRoot, 'manifest.json'), 'utf8'));
  const cycleParityFailures = [];
  for (const id of manifest.cycleFixtures) {
    const fixture = JSON.parse(readFileSync(resolve(fixturesRoot, 'cycle', `${id}.json`), 'utf8'));
    const actual = JSON.parse(await bridge.generateCycle(JSON.stringify(fixture.request)));
    if (canonical(actual) !== canonical(fixture.response)) {
      cycleParityFailures.push({ fixture: id, message: 'bridge response differs from native oracle' });
    }
  }
  const foreverParityFailures = [];
  if (typeof bridge.generateMacrocycle !== 'function') {
    foreverParityFailures.push({
      fixture: 'forever-macrocycle-plan',
      message: 'bridge does not expose generateMacrocycle; Forever parity was not simulated',
    });
  }
  console.log(JSON.stringify({
    status: cycleParityFailures.length || foreverParityFailures.length ? 'failed' : 'passed',
    artifact,
    catalog,
    cycleParityFailures,
    foreverParityFailures,
    contractFailures: [],
  }));
} catch (error) {
  console.log(JSON.stringify({
    status: 'failed',
    artifact,
    catalog,
    cycleParityFailures: [],
    foreverParityFailures: [],
    contractFailures: [{ fixture: '$', message: String(error?.stack ?? error) }],
  }));
  process.exitCode = 1;
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}
