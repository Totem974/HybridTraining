const fs = require('node:fs');
const path = require('node:path');

const {
  SOURCE_ARCHIVE_SHA256,
  assertExactGoldens,
  sha256,
} = require('./golden-format.cjs');

const repositoryRoot = path.resolve(__dirname, '..', '..');
const fixtureRoot = path.join(
  repositoryRoot,
  'test',
  'fixtures',
  'source-calculator-v1',
);
const exactGoldensPath = path.join(fixtureRoot, 'exact-goldens.json');
const checksumsPath = path.join(fixtureRoot, 'checksums.json');
const provenancePath = path.join(fixtureRoot, 'provenance.json');

function main() {
  const exactGoldensBytes = fs.readFileSync(exactGoldensPath);
  const exactGoldens = JSON.parse(exactGoldensBytes.toString('utf8'));
  assertExactGoldens(exactGoldens);

  const checksums = readJson(checksumsPath);
  const checksumEntry = checksums.files.find(
    (entry) => entry.path === 'exact-goldens.json',
  );
  if (!checksumEntry) {
    throw new Error('checksums.json does not protect exact-goldens.json');
  }
  assertEqual(
    checksumEntry.sha256,
    sha256(exactGoldensBytes),
    'exact-goldens.json raw-byte checksum',
  );
  assertEqual(
    checksums.sourceArchive.sha256,
    SOURCE_ARCHIVE_SHA256,
    'checksums source archive SHA-256',
  );

  const provenance = readJson(provenancePath);
  assertEqual(
    provenance.sourceArchive.sha256,
    SOURCE_ARCHIVE_SHA256,
    'provenance source archive SHA-256',
  );
  assertEqual(
    exactGoldens.capture.sourceArchiveSha256,
    SOURCE_ARCHIVE_SHA256,
    'exact goldens source archive SHA-256',
  );

  process.stdout.write(
    `Verified ${exactGoldens.scenarioCount} exact source calculator goldens (${exactGoldens.corpusSha256}).\n`,
  );
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${expected}, got ${actual}`);
  }
}

try {
  main();
} catch (error) {
  console.error(error);
  process.exitCode = 1;
}
