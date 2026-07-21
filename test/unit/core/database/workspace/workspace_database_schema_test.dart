import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/split_local_databases.dart';
import 'package:hybrid_training/core/database/workspace/workspace_database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('deleting an athlete cascades through every workspace child', () async {
    final root = await Directory.systemTemp.createTemp('workspace-delete-');
    addTearDown(() => root.delete(recursive: true));
    final workspace = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openWorkspace();
    addTearDown(workspace.close);

    await _insertAthlete(workspace, id: 'deleted-athlete');
    await _insertAthlete(workspace, id: 'retained-athlete');
    await workspace.insert('weight_profiles', {
      'id': 'weight',
      'athlete_id': 'deleted-athlete',
      'movement_key': 'squat',
      'one_rep_max': 150.0,
      'training_max': 135.0,
      'training_max_ratio': 0.9,
      'unit': 'kg',
      'effective_at': '2026-07-21',
    });
    await workspace.insert('gyms', {
      'id': 'gym',
      'athlete_id': 'deleted-athlete',
      'name': 'Fixture gym',
      'is_default': 1,
    });
    await workspace.insert('bars', {
      'id': 'bar',
      'gym_id': 'gym',
      'name': 'Fixture bar',
      'weight': 20.0,
      'unit': 'kg',
      'quantity': 1,
    });
    await workspace.insert('plates', {
      'id': 'plate',
      'gym_id': 'gym',
      'weight': 20.0,
      'unit': 'kg',
      'quantity': 2,
    });
    await workspace.insert('workspace_drafts', {
      'id': 'draft',
      'athlete_id': 'deleted-athlete',
      'catalog_version_id': 'catalog-v1',
      'catalog_content_hash': 'fixture-hash',
      'catalog_canonicalization_version': 1,
      'payload_schema_version': 1,
      'kind': 'configuration',
      'payload_json': '{}',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });
    await workspace.insert('workspace_draft_equipment', {
      'draft_id': 'draft',
      'athlete_id': 'deleted-athlete',
      'gym_id': 'gym',
      'bar_id': 'bar',
    });
    await workspace.insert('workspace_draft_equipment_ids', {
      'draft_id': 'draft',
      'equipment_id': 'barbell',
    });
    await workspace.insert('workspace_draft_supported_loads', {
      'draft_id': 'draft',
      'load_kind': 'externalWeight',
    });
    await workspace.insert('workspace_draft_assistance', {
      'draft_id': 'draft',
      'assistance_plan_id': 'assistance-plan',
    });
    await workspace.insert('workspace_draft_assistance_selections', {
      'id': 'selection',
      'draft_id': 'draft',
      'slot_id': 'slot',
      'movement_id': 'row',
      'deload_mode': 'omit',
    });
    await workspace.insert('workspace_draft_assistance_prescriptions', {
      'selection_id': 'selection',
      'phase': 'regular',
      'sets': 3,
      'repetition_kind': 'fixed',
      'repetition_minimum': 10,
      'load_kind': 'bodyweight',
    });
    await workspace.insert('workspace_draft_conditioning', {
      'draft_id': 'draft',
      'sequence': 0,
      'definition_id': 'conditioning-definition',
      'modality': 'intervals',
      'work_seconds': 30,
      'rest_seconds': 60,
    });
    await workspace.insert('custom_definitions', {
      'id': 'custom',
      'athlete_id': 'deleted-athlete',
      'schema_version': 1,
      'revision': 1,
      'canonicalization_version': 1,
      'definition_hash': 'fixture-hash',
      'kind': 'template',
      'name': 'Fixture definition',
      'definition_json': '{}',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });
    await workspace.insert('workspace_preferences', {
      'athlete_id': 'deleted-athlete',
      'key': 'fixture-preference',
      'value_json': '{}',
      'updated_at': '2026-07-21',
    });
    await workspace.insert('workspace_migration_quarantine', {
      'id': 'migration-issue',
      'source_schema_version': 1,
      'target_schema_version': 2,
      'athlete_id': 'deleted-athlete',
      'entity_type': 'workspaceDraft',
      'entity_id': 'legacy-draft',
      'issue_code': 'fixture.issue',
      'original_payload': '{broken',
      'original_row_json': '{"payloadJson":"{broken"}',
    });

    expect(
      await workspace.delete(
        'athlete_profiles',
        where: 'id = ?',
        whereArgs: ['deleted-athlete'],
      ),
      1,
    );

    for (final table in {
      'weight_profiles',
      'gyms',
      'bars',
      'plates',
      'workspace_drafts',
      'workspace_draft_equipment',
      'workspace_draft_equipment_ids',
      'workspace_draft_supported_loads',
      'workspace_draft_assistance',
      'workspace_draft_assistance_selections',
      'workspace_draft_assistance_prescriptions',
      'workspace_draft_conditioning',
      'workspace_migration_quarantine',
      'custom_definitions',
      'workspace_preferences',
    }) {
      expect(await workspace.query(table), isEmpty, reason: table);
    }
    expect(
      await workspace.query(
        'athlete_profiles',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: ['retained-athlete'],
      ),
      hasLength(1),
    );
  });

  test('draft provenance, JSON, defaults, and equipment fail closed', () async {
    final root = await Directory.systemTemp.createTemp('workspace-guards-');
    addTearDown(() => root.delete(recursive: true));
    final workspace = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openWorkspace();
    addTearDown(workspace.close);

    await _insertAthlete(workspace, id: 'athlete-a');
    await _insertAthlete(workspace, id: 'athlete-b');
    await workspace.update(
      'athlete_profiles',
      {'rounding_increment': 2.5},
      where: 'id=?',
      whereArgs: ['athlete-a'],
    );
    await expectLater(
      workspace.update(
        'athlete_profiles',
        {'rounding_increment': 0},
        where: 'id=?',
        whereArgs: ['athlete-b'],
      ),
      throwsA(anything),
    );
    expect(
      (await workspace.query(
        'athlete_profiles',
        columns: ['rounding_increment'],
        where: 'id=?',
        whereArgs: ['athlete-a'],
      )).single['rounding_increment'],
      2.5,
    );
    await _insertGym(workspace, id: 'gym-a', athleteId: 'athlete-a');
    await expectLater(
      _insertGym(workspace, id: 'gym-a-duplicate', athleteId: 'athlete-a'),
      throwsA(anything),
    );
    await _insertGym(workspace, id: 'gym-b', athleteId: 'athlete-b');
    await _insertBar(workspace, id: 'bar-a', gymId: 'gym-a');
    await _insertBar(workspace, id: 'bar-b', gymId: 'gym-b');

    await expectLater(
      _insertDraft(workspace, id: 'invalid-json', payloadJson: '{broken'),
      throwsA(anything),
    );
    await expectLater(
      _insertDraft(workspace, id: 'invalid-schema', payloadSchemaVersion: 0),
      throwsA(anything),
    );
    await _insertDraft(workspace, id: 'draft');

    await expectLater(
      workspace.insert('workspace_draft_equipment', {
        'draft_id': 'draft',
        'athlete_id': 'athlete-b',
        'gym_id': 'gym-b',
        'bar_id': 'bar-b',
      }),
      throwsA(anything),
    );
    await expectLater(
      workspace.insert('workspace_draft_equipment', {
        'draft_id': 'draft',
        'athlete_id': 'athlete-a',
        'gym_id': 'gym-a',
        'bar_id': 'bar-b',
      }),
      throwsA(anything),
    );
    await workspace.insert('workspace_draft_equipment', {
      'draft_id': 'draft',
      'athlete_id': 'athlete-a',
      'gym_id': 'gym-a',
      'bar_id': 'bar-a',
    });

    expect(
      (await workspace.query('workspace_draft_equipment')).single,
      containsPair('bar_id', 'bar-a'),
    );
  });

  test(
    'EngineRequest assistance and conditioning inputs are structured',
    () async {
      final root = await Directory.systemTemp.createTemp('workspace-request-');
      addTearDown(() => root.delete(recursive: true));
      final workspace = await SplitLocalDatabases(
        rootPath: root.path,
        factory: databaseFactoryFfi,
      ).openWorkspace();
      addTearDown(workspace.close);

      await _insertAthlete(workspace, id: 'athlete-a');
      await _insertDraft(workspace, id: 'draft');
      await workspace.insert('workspace_draft_assistance', {
        'draft_id': 'draft',
        'assistance_plan_id': 'plan-a',
      });
      await workspace.insert('workspace_draft_assistance_selections', {
        'id': 'selection-a',
        'draft_id': 'draft',
        'slot_id': 'slot-a',
        'movement_id': 'movement-a',
        'deload_mode': 'custom',
      });
      await workspace.insert('workspace_draft_assistance_prescriptions', {
        'selection_id': 'selection-a',
        'phase': 'regular',
        'sets': 3,
        'repetition_kind': 'range',
        'repetition_minimum': 8,
        'repetition_maximum': 12,
        'load_kind': 'externalWeight',
        'load_value': 10.0,
      });
      await workspace.insert('workspace_draft_assistance_prescriptions', {
        'selection_id': 'selection-a',
        'phase': 'deload',
        'sets': 2,
        'repetition_kind': 'amrap',
        'repetition_minimum': 0,
        'load_kind': 'bodyweight',
      });
      await workspace.insert('workspace_draft_conditioning', {
        'draft_id': 'draft',
        'sequence': 0,
        'definition_id': 'conditioning-a',
        'modality': 'distance',
        'target': 1000.0,
      });

      expect(
        await workspace.query('workspace_draft_assistance_prescriptions'),
        hasLength(2),
      );
      expect(
        (await workspace.query('workspace_draft_conditioning')).single,
        allOf(
          containsPair('definition_id', 'conditioning-a'),
          containsPair('target', 1000.0),
        ),
      );
      await expectLater(
        workspace.insert('workspace_draft_conditioning', {
          'draft_id': 'draft',
          'sequence': 1,
          'definition_id': 'invalid-interval',
          'modality': 'intervals',
        }),
        throwsA(anything),
      );
    },
  );

  test('v1 to v2 migration preserves workspace rows', () async {
    final root = await Directory.systemTemp.createTemp('workspace-migration-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/workspace.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => _createWorkspaceV1(db),
      ),
    );
    await _insertAthlete(legacy, id: 'legacy-athlete');
    await legacy.insert('workspace_drafts', {
      'id': 'legacy-draft',
      'athlete_id': 'legacy-athlete',
      'catalog_version_id': 'catalog-v1',
      'catalog_content_hash': 'legacy-hash',
      'kind': 'configuration',
      'payload_json': '{"fixture":true}',
      'created_at': '2026-07-20',
      'updated_at': '2026-07-20',
    });
    await legacy.close();

    final workspace = await SplitLocalDatabases(
      rootPath: root.path,
      factory: databaseFactoryFfi,
    ).openWorkspace();
    addTearDown(workspace.close);

    expect(await workspace.getVersion(), WorkspaceDatabaseSchema.version);
    final migrated = (await workspace.query('workspace_drafts')).single;
    expect(migrated, containsPair('payload_json', '{"fixture":true}'));
    expect(migrated, containsPair('payload_schema_version', 1));
    expect(migrated, containsPair('catalog_canonicalization_version', 1));
    expect(await workspace.query('athlete_profiles'), hasLength(1));
    expect(
      await _tables(workspace),
      containsAll({
        'workspace_draft_equipment',
        'workspace_draft_assistance_selections',
        'workspace_draft_conditioning',
      }),
    );
  });

  test(
    'v1 anomalies are quarantined while other workspace data stays accessible',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'workspace-invalid-migration-',
      );
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/workspace.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
          onCreate: (db, version) => _createWorkspaceV1(db),
        ),
      );
      await _insertAthlete(legacy, id: 'legacy-athlete');
      await legacy.insert('weight_profiles', {
        'id': 'legacy-weight',
        'athlete_id': 'legacy-athlete',
        'movement_key': 'squat',
        'training_max': 100.0,
        'training_max_ratio': 0.9,
        'unit': 'kg',
        'effective_at': '2026-07-20',
      });
      await legacy.insert('gyms', {
        'id': 'legacy-gym-a',
        'athlete_id': 'legacy-athlete',
        'name': 'Legacy gym A',
        'is_default': 1,
      });
      await legacy.insert('gyms', {
        'id': 'legacy-gym-b',
        'athlete_id': 'legacy-athlete',
        'name': 'Legacy gym B',
        'is_default': 1,
      });
      await legacy.insert('bars', {
        'id': 'legacy-bar',
        'gym_id': 'legacy-gym-a',
        'name': 'Legacy bar',
        'weight': 20.0,
        'unit': 'kg',
        'quantity': 1,
      });
      await legacy.insert('plates', {
        'id': 'legacy-plate',
        'gym_id': 'legacy-gym-a',
        'weight': 10.0,
        'unit': 'kg',
        'quantity': 4,
      });
      await legacy.insert('workspace_drafts', {
        'id': 'valid-draft',
        'athlete_id': 'legacy-athlete',
        'catalog_version_id': 'catalog-v1',
        'catalog_content_hash': 'legacy-hash',
        'kind': 'configuration',
        'payload_json': '{"valid":true}',
        'created_at': '2026-07-20',
        'updated_at': '2026-07-20',
      });
      await legacy.insert('workspace_drafts', {
        'id': 'invalid-draft',
        'athlete_id': 'legacy-athlete',
        'catalog_version_id': 'catalog-v1',
        'catalog_content_hash': 'legacy-hash',
        'kind': 'configuration',
        'payload_json': '{broken',
        'created_at': '2026-07-20',
        'updated_at': '2026-07-20',
      });
      await legacy.insert('workspace_preferences', {
        'athlete_id': 'legacy-athlete',
        'key': 'fixture',
        'value_json': '{"retained":true}',
        'updated_at': '2026-07-20',
      });
      await legacy.close();

      final workspace = await SplitLocalDatabases(
        rootPath: root.path,
        factory: databaseFactoryFfi,
      ).openWorkspace();
      addTearDown(workspace.close);

      expect(await workspace.getVersion(), 2);
      expect(
        (await workspace.query('workspace_drafts')).single,
        containsPair('id', 'valid-draft'),
      );
      expect(await workspace.query('weight_profiles'), hasLength(1));
      expect(await workspace.query('bars'), hasLength(1));
      expect(await workspace.query('plates'), hasLength(1));
      expect(await workspace.query('workspace_preferences'), hasLength(1));

      final gyms = await workspace.query('gyms', orderBy: 'id');
      expect(gyms, hasLength(2));
      expect(gyms.map((row) => row['is_default']), everyElement(0));

      final issues = await workspace.query(
        'workspace_migration_quarantine',
        orderBy: 'id',
      );
      expect(issues, hasLength(3));
      expect(
        issues.map((row) => row['issue_code']),
        containsAll({'workspace_draft.invalid_json', 'gym.multiple_defaults'}),
      );
      expect(issues.map((row) => row['status']), everyElement('pending'));
      final invalidDraftIssue = issues.singleWhere(
        (row) => row['entity_id'] == 'invalid-draft',
      );
      expect(invalidDraftIssue['original_payload'], '{broken');
      expect(
        jsonDecode(invalidDraftIssue['original_row_json']! as String),
        containsPair('payloadJson', '{broken'),
      );
    },
  );
}

Future<void> _insertAthlete(Database workspace, {required String id}) =>
    workspace.insert('athlete_profiles', {
      'id': id,
      'display_name': 'Fixture athlete',
      'preferred_unit': 'kg',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });

Future<void> _insertGym(
  Database workspace, {
  required String id,
  required String athleteId,
}) => workspace.insert('gyms', {
  'id': id,
  'athlete_id': athleteId,
  'name': 'Fixture gym',
  'is_default': 1,
});

Future<void> _insertBar(
  Database workspace, {
  required String id,
  required String gymId,
}) => workspace.insert('bars', {
  'id': id,
  'gym_id': gymId,
  'name': 'Fixture bar',
  'weight': 20.0,
  'unit': 'kg',
  'quantity': 1,
});

Future<void> _insertDraft(
  Database workspace, {
  required String id,
  String payloadJson = '{}',
  int payloadSchemaVersion = 1,
}) => workspace.insert('workspace_drafts', {
  'id': id,
  'athlete_id': 'athlete-a',
  'catalog_version_id': 'catalog-v1',
  'catalog_content_hash': 'fixture-hash',
  'catalog_canonicalization_version': 1,
  'payload_schema_version': payloadSchemaVersion,
  'kind': 'configuration',
  'payload_json': payloadJson,
  'created_at': '2026-07-21',
  'updated_at': '2026-07-21',
});

Future<void> _createWorkspaceV1(DatabaseExecutor db) async {
  await db.execute(
    '''CREATE TABLE athlete_profiles (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, preferred_unit TEXT NOT NULL CHECK(preferred_unit IN ('kg','lb')), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
  );
  await db.execute(
    '''CREATE TABLE weight_profiles (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, movement_key TEXT NOT NULL, one_rep_max REAL CHECK(one_rep_max>0), training_max REAL NOT NULL CHECK(training_max>0), training_max_ratio REAL NOT NULL CHECK(training_max_ratio>0 AND training_max_ratio<=1), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), effective_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE, UNIQUE(athlete_id,movement_key,effective_at))''',
  );
  await db.execute(
    '''CREATE TABLE gyms (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, name TEXT NOT NULL, is_default INTEGER NOT NULL CHECK(is_default IN (0,1)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE bars (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, name TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE plates (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>=0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE workspace_drafts (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, catalog_version_id TEXT NOT NULL, catalog_content_hash TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('configuration','schedule','templateOverlay','moduleOverlay')), payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE custom_definitions (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, authority TEXT NOT NULL DEFAULT 'userCustom' CHECK(authority='userCustom'), parent_definition_id TEXT, parent_catalog_version_id TEXT, parent_catalog_content_hash TEXT, schema_version INTEGER NOT NULL CHECK(schema_version > 0), revision INTEGER NOT NULL CHECK(revision > 0), canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version > 0), definition_hash TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('template','module')), name TEXT NOT NULL, definition_json TEXT NOT NULL CHECK(json_valid(definition_json)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, CHECK((parent_definition_id IS NULL AND parent_catalog_version_id IS NULL AND parent_catalog_content_hash IS NULL) OR (parent_definition_id IS NOT NULL AND parent_catalog_version_id IS NOT NULL AND parent_catalog_content_hash IS NOT NULL)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE workspace_preferences (athlete_id TEXT NOT NULL, key TEXT NOT NULL, value_json TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(athlete_id,key), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
  );
  await db.execute(
    'CREATE INDEX weight_profiles_athlete_idx ON weight_profiles(athlete_id,movement_key,effective_at)',
  );
  await db.execute(
    'CREATE INDEX workspace_drafts_athlete_idx ON workspace_drafts(athlete_id,updated_at)',
  );
  await db.execute(
    'CREATE INDEX custom_definitions_athlete_idx ON custom_definitions(athlete_id,updated_at)',
  );
}

Future<Set<Object?>> _tables(Database db) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type='table'",
)).map((row) => row['name']).toSet();
