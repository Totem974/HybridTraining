import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const fixturesRoot = resolve(process.argv[2] ?? 'test/fixtures/engine-v1');
const nativeCycleCorpus = process.argv[3] ? resolve(process.argv[3]) : undefined;
const nativeForeverResponse = process.argv[4] ? resolve(process.argv[4]) : undefined;
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
  if (!nativeCycleCorpus || !existsSync(nativeCycleCorpus)) {
    throw new Error('Native public Cycle parity corpus is unavailable.');
  }
  const corpus = JSON.parse(readFileSync(nativeCycleCorpus, 'utf8'));
  if (
    corpus.corpusVersion !== 1 ||
    !Array.isArray(corpus.cycleCases) ||
    corpus.expectedCycleCaseCount !== manifest.cycleFixtures.length
  ) {
    throw new Error('Native public Cycle parity corpus is invalid or incomplete.');
  }
  const cycleParityFailures = [];
  const contractFailures = [];
  const expectedIds = [...manifest.cycleFixtures].sort();
  const actualIds = corpus.cycleCases.map(({ id }) => id).sort();
  if (canonical(actualIds) !== canonical(expectedIds)) {
    contractFailures.push({
      fixture: 'cycle-corpus',
      message: 'Public Cycle corpus does not cover the complete fixture manifest.',
      expectedIds,
      actualIds,
    });
  }
  for (const parityCase of corpus.cycleCases) {
    const { id, request, expected } = parityCase;
    let actual;
    try {
      actual = JSON.parse(await bridge.generateCycle(JSON.stringify(request)));
    } catch (error) {
      contractFailures.push({
        fixture: id,
        message: 'JavaScript bridge rejected the native-valid public request.',
        error: String(error?.stack ?? error),
        request,
      });
      continue;
    }
    const expectedCanonical = canonical(expected);
    const actualCanonical = canonical(actual);
    if (actualCanonical !== expectedCanonical) {
      cycleParityFailures.push({
        fixture: id,
        message: 'JavaScript bridge response differs from native Dart bridge response.',
        firstDifference: firstDifference(expected, actual),
        expectedLogicalHash: expected.snapshot?.logicalHash,
        actualLogicalHash: actual.snapshot?.logicalHash,
        expectedLength: expectedCanonical.length,
        actualLength: actualCanonical.length,
      });
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
    cycleFixtureCount: corpus.cycleCases.length,
    expectedCycleFixtureCount: manifest.cycleFixtures.length,
    cycleParityFailures,
    foreverParityFailures,
    contractFailures,
  }));
  // The compiled Dart runtime may retain Node event-loop handles after all
  // bridge calls complete. This runner is a one-shot process, so terminate
  // explicitly once its complete JSON report has been written.
  process.exit(0);
} catch (error) {
  console.log(JSON.stringify({
    status: 'failed',
    artifact,
    catalog,
    cycleParityFailures: [],
    foreverParityFailures: [],
    contractFailures: [{ fixture: '$', message: String(error?.stack ?? error) }],
  }));
  process.exit(1);
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function firstDifference(expected, actual, path = '$') {
  if (Object.is(expected, actual)) return undefined;
  if (Array.isArray(expected) || Array.isArray(actual)) {
    if (!Array.isArray(expected) || !Array.isArray(actual)) {
      return { path, expectedType: typeOf(expected), actualType: typeOf(actual) };
    }
    if (expected.length !== actual.length) {
      return { path: `${path}.length`, expected: expected.length, actual: actual.length };
    }
    for (let index = 0; index < expected.length; index += 1) {
      const difference = firstDifference(expected[index], actual[index], `${path}[${index}]`);
      if (difference) return difference;
    }
    return { path, expected, actual };
  }
  if (
    expected && typeof expected === 'object' ||
    actual && typeof actual === 'object'
  ) {
    if (!expected || typeof expected !== 'object' || !actual || typeof actual !== 'object') {
      return { path, expectedType: typeOf(expected), actualType: typeOf(actual) };
    }
    const keys = [...new Set([...Object.keys(expected), ...Object.keys(actual)])].sort();
    for (const key of keys) {
      if (!(key in expected) || !(key in actual)) {
        return {
          path: `${path}.${key}`,
          expected: key in expected ? expected[key] : '<missing>',
          actual: key in actual ? actual[key] : '<missing>',
        };
      }
      const difference = firstDifference(expected[key], actual[key], `${path}.${key}`);
      if (difference) return difference;
    }
  }
  return { path, expected, actual };
}

function typeOf(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  return typeof value;
}
