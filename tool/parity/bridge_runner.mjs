import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const fixturesRoot = resolve(process.argv[2] ?? 'test/fixtures/engine-v1');
const nativeForeverResponse = process.argv[3] ? resolve(process.argv[3]) : undefined;
const candidates = [
  process.env.TRAINING_ENGINE_BRIDGE,
  'packages/training_engine_web_bridge/build/engine_bridge.js',
  'packages/training_engine_web_bridge/build/training_engine_bridge.js',
  'apps/web_generator/public/engine/hybrid_training_engine.js',
].filter(Boolean).map((candidate) => resolve(candidate));
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
].filter(Boolean).map((candidate) => resolve(candidate));
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
  const bridge = module.trainingEngineBridge ?? module.default ?? globalThis.hybridTrainingEngine;
  if (!bridge || typeof bridge.initialize !== 'function' || typeof bridge.generateCycle !== 'function') {
    throw new Error('Artifact does not expose initialize(catalogJson) and generateCycle(requestJson).');
  }
  JSON.parse(await bridge.initialize(readFileSync(catalog, 'utf8')));
  const manifest = JSON.parse(readFileSync(resolve(fixturesRoot, 'manifest.json'), 'utf8'));
  const cycleParityFailures = [];
  const contractFailures = [];
  for (const id of manifest.cycleFixtures) {
    const fixture = JSON.parse(readFileSync(resolve(fixturesRoot, 'cycle', `${id}.json`), 'utf8'));
    const bridgeRequest = {
      ...fixture.request,
      apiVersion: 'v1',
      schemaVersion: 1,
      templateId: fixture.catalogSelection.templateId,
      variantId: fixture.catalogSelection.variantId,
    };
    const actual = JSON.parse(await bridge.generateCycle(JSON.stringify(bridgeRequest)));
    if (
      canonical(actual.cycle) !== canonical(fixture.response) ||
      canonical(actual.snapshot?.payload) !== canonical(fixture.snapshot)
    ) {
      cycleParityFailures.push({ fixture: id, message: 'bridge response differs from native oracle' });
    }
  }
  const foreverParityFailures = [];
  if (typeof bridge.generateMacrocycle !== 'function') {
    foreverParityFailures.push({
      fixture: 'forever-macrocycle-plan',
      message: 'bridge does not expose generateMacrocycle; Forever parity was not simulated',
    });
  } else {
    const foreverRequestPath = resolve('contracts/v1/fixtures/forever_request.valid.json');
    const native = nativeForeverResponse && existsSync(nativeForeverResponse)
      ? { status: 0, stdout: readFileSync(nativeForeverResponse, 'utf8'), stderr: '' }
      : spawnSync(
          process.env.DART_EXECUTABLE ?? 'dart',
          ['run', 'packages/training_engine_web_bridge/tool/generate_forever_response.dart', catalog, foreverRequestPath],
          { cwd: resolve('.'), encoding: 'utf8', timeout: 120_000 },
        );
    if (native.status !== 0 || !native.stdout.trim()) {
      contractFailures.push({
        fixture: 'forever_request.valid.json',
        message: 'native Forever runner failed',
        stderr: native.stderr,
      });
    } else {
      const request = readFileSync(foreverRequestPath, 'utf8');
      const actual = JSON.parse(await bridge.generateMacrocycle(request));
      const expected = JSON.parse(native.stdout);
      if (canonical(actual) !== canonical(expected)) {
        foreverParityFailures.push({
          fixture: 'forever_request.valid.json',
          message: 'bridge Forever response differs from native Dart response',
          expectedLogicalHash: expected.snapshot?.logicalHash,
          actualLogicalHash: actual.snapshot?.logicalHash,
          expectedCatalogHash: expected.catalogHash,
          actualCatalogHash: actual.catalogHash,
          expectedLength: canonical(expected).length,
          actualLength: canonical(actual).length,
        });
      }
    }
  }
  console.log(JSON.stringify({
    status: cycleParityFailures.length || foreverParityFailures.length || contractFailures.length ? 'failed' : 'passed',
    artifact,
    catalog,
    cycleParityFailures,
    foreverParityFailures,
    contractFailures,
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
