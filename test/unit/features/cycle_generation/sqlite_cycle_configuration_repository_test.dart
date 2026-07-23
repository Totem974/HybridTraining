import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/storage/sqlite_database_file.dart';
import 'package:hybrid_training/features/cycle_generation/data/sqlite_cycle_configuration_repository.dart';
import 'package:hybrid_training/features/cycle_generation/data/workspace_database_schema.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_configuration_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late SqliteDatabaseFile file;
  late SqliteCycleConfigurationRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cycle-configurations-');
    file = SqliteDatabaseFile(
      fileName: 'workspace.db',
      version: WorkspaceDatabaseSchema.version,
      onCreate: WorkspaceDatabaseSchema.create,
      onUpgrade: WorkspaceDatabaseSchema.upgrade,
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/workspace.db',
    );
    repository = SqliteCycleConfigurationRepository(file);
  });

  tearDown(() async {
    await file.close();
    await directory.delete(recursive: true);
  });

  test(
    'opaque configuration JSON survives create, update, and reopen',
    () async {
      final originalJson = _configurationJson(
        templateId: 'classic_boring_but_big',
      );
      final created = _record(configurationJson: originalJson);
      await repository.create(created);
      await file.close();

      final reopened = SqliteCycleConfigurationRepository(file);
      final loaded = await reopened.find('cycle-1');
      expect(loaded?.configurationJson, originalJson);
      expect(loaded?.profileId, isNull);
      expect(loaded?.createdAt, created.createdAt);

      final updatedJson = _configurationJson(templateId: 'classic_full_body');
      await reopened.update(
        _record(
          name: 'Full Body',
          configurationJson: updatedJson,
          createdAt: DateTime.utc(2020),
          updatedAt: DateTime.utc(2026, 7, 24),
        ),
      );
      final updated = await reopened.find('cycle-1');
      expect(updated?.name, 'Full Body');
      expect(updated?.configurationJson, updatedJson);
      expect(updated?.createdAt, created.createdAt);
    },
  );

  test('archive keeps history and hides it from active listing', () async {
    await repository.create(_record());

    await repository.archive('cycle-1', DateTime.utc(2026, 7, 25));

    expect(await repository.list(), isEmpty);
    final history = await repository.list(includeArchived: true);
    expect(history, hasLength(1));
    expect(history.single.archivedAt, DateTime.utc(2026, 7, 25));
    expect(await repository.find('cycle-1'), isNotNull);
  });

  test('accepts every canonical max input mode', () async {
    for (final mode in const ['oneRepMax', 'directTrainingMax', 'repMax']) {
      final id = 'cycle-$mode';
      await repository.create(
        _record(
          id: id,
          configurationJson: _configurationJson(maxMode: mode),
        ),
      );
      expect(await repository.find(id), isNotNull);
    }
  });

  test('rejects malformed or mismatched configuration envelopes', () async {
    expect(
      () => repository.create(_record(configurationJson: '{}')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.create(
        _record(
          configurationJson:
              '{"format":"hybrid-training-cycle","configurationVersion":2,'
              '"catalogVersion":7,"catalogHash":"sha256:catalog"}',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.create(
        _record(
          configurationJson:
              '{"format":"hybrid-training-cycle","configurationVersion":1,'
              '"catalogVersion":7,"catalogHash":"sha256:catalog"}',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => repository.create(
        _record(
          configurationJson: jsonEncode({
            ...jsonDecode(_configurationJson(templateId: 'classic_full_body'))
                as Map<String, Object?>,
            'unexpected': true,
          }),
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

CycleConfigurationRecord _record({
  String id = 'cycle-1',
  String name = 'Cycle',
  String? configurationJson,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 7, 23);
  return CycleConfigurationRecord(
    id: id,
    profileId: null,
    name: name,
    formatVersion: 1,
    catalogVersion: 7,
    catalogHash: 'sha256:catalog',
    configurationJson: configurationJson ?? _configurationJson(),
    createdAt: created,
    updatedAt: updatedAt ?? created,
    archivedAt: null,
  );
}

String _configurationJson({
  String templateId = 'classic_boring_but_big',
  String maxMode = 'oneRepMax',
}) => jsonEncode({
  'format': 'hybrid-training-cycle',
  'configurationVersion': 1,
  'catalogVersion': 7,
  'catalogHash': 'sha256:catalog',
  'template': {
    'id': templateId,
    'variantId': 'original',
    'options': <String, Object?>{},
  },
  'commonOptions': {
    'warmUp': <String, Object?>{'enabled': true},
    'joker': <String, Object?>{'enabled': false},
    'deload': <String, Object?>{'enabled': true},
  },
  'maxes': {
    'mode': maxMode,
    'globalTrainingMaxRatioBasisPoints': 9000,
    'values': <String, Object?>{},
  },
  'schedule': {
    'id': 'four_days',
    'startDate': '2026-07-27T00:00:00.000Z',
    'sessionOrder': <Object?>['overhead_press', 'deadlift'],
  },
  'equipment': {'unit': 'kg', 'barProfileId': 'default_kg'},
  'output': {'title': '5/3/1', 'showPlating': false},
});
