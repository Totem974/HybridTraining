import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/split_local_databases.dart';
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
      'kind': 'configuration',
      'payload_json': '{}',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
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
}

Future<void> _insertAthlete(Database workspace, {required String id}) =>
    workspace.insert('athlete_profiles', {
      'id': id,
      'display_name': 'Fixture athlete',
      'preferred_unit': 'kg',
      'created_at': '2026-07-21',
      'updated_at': '2026-07-21',
    });
