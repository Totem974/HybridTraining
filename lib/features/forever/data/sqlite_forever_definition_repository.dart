import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import 'package:training_engine/features/forever/domain/forever_contract.dart';

final class SqliteForeverDefinitionRepository
    implements ForeverDefinitionRepository {
  const SqliteForeverDefinitionRepository(this.database);

  final Database database;

  @override
  Future<List<ResolvedForeverDefinition>> loadPublishedDefinitions(
    int catalogVersion,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT e.payload_json FROM catalog_library_entries e
      JOIN catalog_versions v ON v.version=e.version
      WHERE e.version=? AND e.kind='foreverDefinitions'
        AND v.status='published'
      ORDER BY e.id''',
      [catalogVersion],
    );
    return rows
        .map((row) => _decode(row['payload_json']! as String))
        .toList(growable: false);
  }

  @override
  Future<ResolvedForeverDefinition> resolve({
    required int catalogVersion,
    required ForeverDefinitionId id,
    required ForeverDefinitionRevision revision,
  }) async {
    final rows = await database.query(
      'catalog_library_entries',
      columns: ['revision', 'payload_json'],
      where: 'version=? AND kind=? AND id=?',
      whereArgs: [catalogVersion, 'foreverDefinitions', id.value],
      limit: 1,
    );
    if (rows.isEmpty || rows.single['revision'] != revision.value) {
      throw StateError(
        'Published Forever definition ${id.value}@${revision.value} not found.',
      );
    }
    return _decode(rows.single['payload_json']! as String);
  }

  ResolvedForeverDefinition _decode(String source) {
    final json = (jsonDecode(source) as Map).cast<String, Object?>();
    final id = ForeverDefinitionId(json['id']! as String);
    final revision = ForeverDefinitionRevision(json['revision']! as int);
    final labels = (json['labels']! as Map).cast<String, Object?>();
    final phases = (json['phases']! as List<Object?>)
        .map((raw) {
          final phase = (raw! as Map).cast<String, Object?>();
          final cycle = (phase['cycle']! as Map).cast<String, Object?>();
          final reference = ForeverCycleReference(
            templateId: cycle['templateId']! as String,
            variantId: cycle['variantId']! as String,
            templateRevision: cycle['templateRevision']! as int,
            variantRevision: cycle['variantRevision']! as int,
          );
          final role = ForeverPhaseRole.values.byName(phase['role']! as String);
          final slot = ForeverCycleSlot(
            id: phase['id']! as String,
            role: role,
            repeatCount: phase['repeatCount']! as int,
            defaultCycle: reference,
            allowedCycles: [reference],
            transition: ForeverTransition(
              trainingMaxRule: _trainingMaxRule(
                (phase['trainingMaxRule']! as Map).cast<String, Object?>(),
              ),
              requiresConfirmation: role == ForeverPhaseRole.test,
            ),
          );
          return ForeverPhase(id: phase['id']! as String, slots: [slot]);
        })
        .toList(growable: false);
    return ResolvedForeverDefinition(
      id: id,
      revision: revision,
      labelEn: labels['en']! as String,
      labelFr: labels['fr']! as String,
      sourceRuleIds: (json['sourceRuleIds']! as List<Object?>).cast<String>(),
      phases: phases,
      editorSchema: ForeverEditorSchema(
        definitionId: id,
        revision: revision,
        configurableSlotIds: [
          for (final phase in phases)
            for (final slot in phase.slots) slot.id,
        ],
      ),
    );
  }

  TrainingMaxRule _trainingMaxRule(Map<String, Object?> json) {
    return switch (json['type']) {
      'keep' => const KeepTrainingMax(),
      'add' => AddTrainingMax({
        const MovementId('overhead_press'): Weight(
          ((json['upperBody']! as num) * 100).round(),
          WeightUnit.values.byName(json['unit']! as String),
        ),
        const MovementId('bench_press'): Weight(
          ((json['upperBody']! as num) * 100).round(),
          WeightUnit.values.byName(json['unit']! as String),
        ),
        const MovementId('deadlift'): Weight(
          ((json['lowerBody']! as num) * 100).round(),
          WeightUnit.values.byName(json['unit']! as String),
        ),
        const MovementId('squat'): Weight(
          ((json['lowerBody']! as num) * 100).round(),
          WeightUnit.values.byName(json['unit']! as String),
        ),
      }, resultKind: _valueKind(json)),
      'multiply' => MultiplyTrainingMax(
        ((json['ratios']! as Map).cast<String, Object?>()).map(
          (movement, ratio) => MapEntry(
            MovementId(movement),
            Percentage(((ratio as num) * 100).round()),
          ),
        ),
        resultKind: _valueKind(json),
      ),
      'testThenConfirm' => const TestThenConfirmTrainingMax(),
      _ => throw FormatException(
        'Unsupported Forever TM rule ${json['type']}.',
      ),
    };
  }

  TrainingMaxValueKind _valueKind(Map<String, Object?> json) =>
      TrainingMaxValueKind.values.byName(
        (json['valueState'] as String?) ?? 'projected',
      );
}
