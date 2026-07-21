import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/training/training_database_schema.dart';
import 'package:hybrid_training/core/database/training/training_plan_snapshot_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: TrainingDatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => TrainingDatabaseSchema.create(db),
      ),
    );
  });
  tearDown(() => database.close());

  test('canonical JSON v1 sorts keys and normalizes equivalent numbers', () {
    const source = '{"b":2.0,"a":1,"nested":{"zero":-0.0,"list":[3.0]}}';
    expect(
      TrainingSnapshotIntegrity.canonicalize(source),
      '{"a":1,"b":2,"nested":{"list":[3],"zero":0}}',
    );
    expect(
      TrainingSnapshotIntegrity.hash('{"b":2,"a":1}'),
      '43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777',
    );
  });

  test('writes only the canonical JSON and its verified SHA-256', () async {
    const source =
        '{"template":{"revision":1.0,"id":"standard"},'
        '"schemaVersion":1,"schedule":{"sessions":[{"sequence":0,'
        '"offsetDays":0,"id":"session-1","blocks":[{"sequence":0,'
        '"kind":"main","id":"block-1"}]}]},'
        '"catalogVersionId":"catalog-v1",'
        '"catalogContentHash":"catalog-hash"}';
    final hash = TrainingSnapshotIntegrity.hash(source);

    await const TrainingPlanSnapshotRepository().create(
      database,
      _write(snapshotJson: source, snapshotHash: hash),
    );

    final row = (await database.query('plans')).single;
    expect(
      row['resolved_snapshot_json'],
      '{"catalogContentHash":"catalog-hash",'
      '"catalogVersionId":"catalog-v1",'
      '"schedule":{"sessions":[{"blocks":[{"id":"block-1",'
      '"kind":"main","sequence":0}],"id":"session-1",'
      '"offsetDays":0,"sequence":0}]},"schemaVersion":1,'
      '"template":{"id":"standard","revision":1}}',
    );
    expect(row['resolved_snapshot_hash'], hash);
    expect(row['snapshot_schema_version'], 1);
    expect(row['snapshot_canonicalization_version'], 1);
    expect(row['snapshot_hash_algorithm'], 'sha256');
  });

  test('rejects a plausible but false hash before writing', () async {
    await expectLater(
      const TrainingPlanSnapshotRepository().create(
        database,
        _write(snapshotHash: '0' * 64),
      ),
      throwsA(
        isA<TrainingSnapshotWriteException>().having(
          (error) => error.code,
          'code',
          'snapshot.hash_mismatch',
        ),
      ),
    );
    expect(await database.query('plans'), isEmpty);
  });

  test('rejects non-canonical hash text before writing', () async {
    final uppercase = TrainingSnapshotIntegrity.hash(
      _validSnapshotJson,
    ).toUpperCase();
    await expectLater(
      const TrainingPlanSnapshotRepository().create(
        database,
        _write(snapshotHash: uppercase),
      ),
      throwsA(
        isA<TrainingSnapshotWriteException>().having(
          (error) => error.code,
          'code',
          'snapshot.hash_not_canonical',
        ),
      ),
    );
    expect(await database.query('plans'), isEmpty);
  });

  test('fails closed on unsupported integrity contract versions', () async {
    final hash = TrainingSnapshotIntegrity.hash(_validSnapshotJson);
    final cases = <(TrainingPlanSnapshotWrite, String)>[
      (
        _write(snapshotHash: hash, snapshotSchemaVersion: 2),
        'snapshot.unsupported_schema_version',
      ),
      (
        _write(snapshotHash: hash, snapshotCanonicalizationVersion: 2),
        'snapshot.unsupported_canonicalization_version',
      ),
      (
        _write(snapshotHash: hash, snapshotHashAlgorithm: 'sha512'),
        'snapshot.unsupported_hash_algorithm',
      ),
    ];

    for (final (write, code) in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(database, write),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            code,
          ),
        ),
      );
    }
    expect(await database.query('plans'), isEmpty);
  });

  test('rejects malformed and non-object snapshot JSON', () async {
    final cases = <(String, String)>[
      ('{bad', 'snapshot.invalid_json'),
      ('[1,2,3]', 'snapshot.not_object'),
    ];
    for (final (source, code) in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(
          database,
          _write(snapshotJson: source, snapshotHash: '0' * 64),
        ),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            code,
          ),
        ),
      );
    }
    expect(await database.query('plans'), isEmpty);
  });

  test('rejects empty or incomplete resolved snapshots', () async {
    final cases = <String>[
      '{}',
      '{"schemaVersion":1,"catalogVersionId":"catalog-v1",'
          '"catalogContentHash":"catalog-hash","template":{},'
          '"schedule":{"sessions":[]}}',
      '{"schemaVersion":1,"catalogVersionId":"catalog-v1",'
          '"catalogContentHash":"catalog-hash",'
          '"template":{"id":"standard","revision":1},'
          '"schedule":{"sessions":[]}}',
      '{"schemaVersion":1,"catalogVersionId":"catalog-v1",'
          '"catalogContentHash":"catalog-hash",'
          '"template":{"id":"standard","revision":1},'
          '"schedule":{"sessions":[{"id":"session-1",'
          '"sequence":0,"offsetDays":0,"blocks":[]}]}}',
    ];
    for (final source in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(
          database,
          _write(
            snapshotJson: source,
            snapshotHash: TrainingSnapshotIntegrity.hash(source),
          ),
        ),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'snapshot.invalid_structure',
          ),
        ),
      );
    }
  });

  test('rejects PII, source, proof, excerpt and all unknown keys', () async {
    final cases = <String>[
      _validSnapshotJson.replaceFirst(
        '"schemaVersion":1',
        '"schemaVersion":1,"email":"fixture@example.invalid"',
      ),
      _validSnapshotJson.replaceFirst(
        '"revision":1',
        '"revision":1,"source":"book"',
      ),
      _validSnapshotJson.replaceFirst(
        '"offsetDays":0',
        '"offsetDays":0,"proof":{}',
      ),
      _validSnapshotJson.replaceFirst(
        '"kind":"main"',
        '"kind":"main","excerpt":"forbidden"',
      ),
      _validSnapshotJson.replaceFirst(
        '"kind":"main"',
        '"kind":"main","unknown":true',
      ),
    ];
    for (final source in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(
          database,
          _write(
            snapshotJson: source,
            snapshotHash: TrainingSnapshotIntegrity.hash(source),
          ),
        ),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'snapshot.unknown_key',
          ),
        ),
      );
    }
  });

  test('requires snapshot catalog identity to match plan metadata', () async {
    final cases = <String>[
      _validSnapshotJson.replaceFirst('catalog-v1', 'catalog-v2'),
      _validSnapshotJson.replaceFirst('catalog-hash', 'other-hash'),
    ];
    for (final source in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(
          database,
          _write(
            snapshotJson: source,
            snapshotHash: TrainingSnapshotIntegrity.hash(source),
          ),
        ),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'snapshot.identity_mismatch',
          ),
        ),
      );
    }
  });

  test('a plan can only be created as an incomplete draft', () async {
    final hash = TrainingSnapshotIntegrity.hash(_validSnapshotJson);
    final cases = <TrainingPlanSnapshotWrite>[
      _write(snapshotHash: hash, status: 'scheduled'),
      _write(snapshotHash: hash, completedAt: '2026-07-21T01:00:00Z'),
    ];
    for (final write in cases) {
      await expectLater(
        const TrainingPlanSnapshotRepository().create(database, write),
        throwsA(
          isA<TrainingSnapshotWriteException>().having(
            (error) => error.code,
            'code',
            'plan.invalid_initial_status',
          ),
        ),
      );
    }
  });
}

TrainingPlanSnapshotWrite _write({
  String snapshotJson = _validSnapshotJson,
  required String snapshotHash,
  int snapshotSchemaVersion = 1,
  int snapshotCanonicalizationVersion = 1,
  String snapshotHashAlgorithm = 'sha256',
  String status = 'draft',
  String? completedAt,
}) => TrainingPlanSnapshotWrite(
  id: 'plan-1',
  athleteId: 'athlete-1',
  catalogVersionId: 'catalog-v1',
  catalogContentHash: 'catalog-hash',
  snapshotSchemaVersion: snapshotSchemaVersion,
  snapshotCanonicalizationVersion: snapshotCanonicalizationVersion,
  snapshotHashAlgorithm: snapshotHashAlgorithm,
  resolvedSnapshotHash: snapshotHash,
  resolvedSnapshotJson: snapshotJson,
  startsOn: '2026-07-21',
  status: status,
  createdAt: '2026-07-21T00:00:00Z',
  completedAt: completedAt,
);

const _validSnapshotJson =
    '{"schemaVersion":1,"catalogVersionId":"catalog-v1",'
    '"catalogContentHash":"catalog-hash",'
    '"template":{"id":"standard","revision":1},'
    '"schedule":{"sessions":[{"id":"session-1","sequence":0,'
    '"offsetDays":0,"blocks":[{"id":"block-1","sequence":0,'
    '"kind":"main"}]}]}}';
