import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/import_export/data/sqlite_backup_manager.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart';
import 'package:hybrid_training/features/programs/domain/program_generator_factory.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/training_max/domain/max_calculator.dart';
import 'package:sqflite/sqflite.dart';

class SqliteTrainingStore implements TrainingStore {
  SqliteTrainingStore({required this.localDatabase, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _athleteId = 'local-athlete';
  static const _programId = 'forever-original-fsl-v1';

  final LocalDatabase localDatabase;
  final DateTime Function() _clock;

  SqliteBackupManager get _backupManager =>
      SqliteBackupManager(localDatabase: localDatabase, clock: _clock);

  @override
  Future<void> initialize() async {
    final database = await localDatabase.open();
    final now = _clock().toUtc().toIso8601String();
    for (final lift in MainLift.values) {
      await database.insert('exercises', {
        'id': lift.name,
        'name_key': 'lift.${lift.name}',
        'category': 'main_lift',
        'is_main_lift': 1,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await database.insert('program_definitions', {
      'id': _programId,
      'schema_version': 1,
      'name_key': ProgramDefinitionRef.originalFsl.labelKey,
      'definition_json': jsonEncode({
        'format': 'hybrid-training-program',
        'schemaVersion': 1,
        'id': _programId,
        'nameKey': ProgramDefinitionRef.originalFsl.labelKey,
        'family': 'forever',
        'labelKey': ProgramDefinitionRef.originalFsl.labelKey,
        'validationStatus': 'rulesReviewed',
        'references': [
          {
            'title': '5/3/1 Forever',
            'bookPages': '168-170',
            'pdfPages': '180-182',
          },
        ],
        'source': {'book': '5/3/1 Forever', 'pages': '168-170'},
        'model': 'original-351-fsl',
        'trainingMax': {'minimumRatio': 0.85, 'maximumRatio': 0.90},
        'weeks': [1, 2, 3],
      }),
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<bool> hasProfile() async {
    final database = await localDatabase.open();
    final count = Sqflite.firstIntValue(
      await database.rawQuery(
        'SELECT COUNT(*) FROM athlete_profiles WHERE deleted_at IS NULL',
      ),
    );
    return (count ?? 0) > 0;
  }

  @override
  Future<void> createFoundation(FoundationProfileInput input) async {
    if (input.displayName.trim().isEmpty ||
        input.oneRepMaxes.length != MainLift.values.length ||
        input.oneRepMaxes.values.any((value) => value <= 0)) {
      throw ArgumentError('A name and four positive maxes are required.');
    }
    const catalog = ProgramCatalog();
    final preset = catalog.preset(input.persistentPresetId);
    if (input.presetVersion != preset.version) {
      throw ArgumentError.value(input.presetVersion, 'presetVersion');
    }
    if (input.trainingDaysPerWeek != 3 && input.trainingDaysPerWeek != 4) {
      throw ArgumentError.value(
        input.trainingDaysPerWeek,
        'trainingDaysPerWeek',
      );
    }
    if (!preset.supportedFrequencies.contains(input.trainingDaysPerWeek)) {
      throw ArgumentError.value(
        input.trainingDaysPerWeek,
        'trainingDaysPerWeek',
      );
    }
    final program = const ProgramGeneratorFactory().resolve(
      input.persistentPresetId,
    );
    final database = await localDatabase.open();
    final now = _clock().toUtc();
    final startsOn = DateTime(
      input.startDate.year,
      input.startDate.month,
      input.startDate.day,
    );
    final cycleId = 'cycle-${now.microsecondsSinceEpoch}';
    final unit = input.unit == WeightUnit.kilograms ? 'kg' : 'lb';
    final rounder = LoadRounder(increment: input.roundingIncrement);

    await database.transaction((transaction) async {
      await transaction.insert('athlete_profiles', {
        'id': _athleteId,
        'display_name': input.displayName.trim(),
        'preferred_unit': unit,
        'rounding_increment': input.roundingIncrement,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final lift in MainLift.values) {
        final oneRepMax = input.oneRepMaxes[lift]!;
        final liftMax = LiftMax(
          lift: lift,
          oneRepMax: oneRepMax,
          trainingMaxRatio: 0.9,
          unit: input.unit,
        );
        await transaction.insert('training_max_history', {
          'id': 'tm-${lift.name}-${now.microsecondsSinceEpoch}',
          'athlete_id': _athleteId,
          'exercise_id': lift.name,
          'one_rep_max': oneRepMax,
          'training_max': liftMax.trainingMax,
          'unit': unit,
          'effective_at': now.toIso8601String(),
        });
      }
      await transaction.insert('training_cycles', {
        'id': cycleId,
        'athlete_id': _athleteId,
        'program_definition_id': input.persistentPresetId,
        'program_definition_version': input.presetVersion,
        'starts_on': _dateOnly(startsOn),
        'status': 'active',
        'settings_json': jsonEncode({
          'unit': unit,
          'roundingIncrement': input.roundingIncrement,
          'trainingMaxRatio': 0.9,
          'supplementalSets': 5,
          'trainingDaysPerWeek': input.trainingDaysPerWeek,
        }),
        'created_at': now.toIso8601String(),
      });

      var sessionIndex = 0;
      final weeklyOffsets = input.trainingDaysPerWeek == 4
          ? const [0, 1, 3, 5]
          : const [0, 2, 4];
      for (var week = 1; week <= 3; week++) {
        for (final lift in MainLift.values) {
          final sessionId = '$cycleId-w$week-${lift.name}';
          final liftMax = LiftMax(
            lift: lift,
            oneRepMax: input.oneRepMaxes[lift]!,
            trainingMaxRatio: 0.9,
            unit: input.unit,
          );
          final generated = program.buildSession(
            week: week,
            liftMax: liftMax,
            rounder: rounder,
          );
          await transaction.insert('training_sessions', {
            'id': sessionId,
            'cycle_id': cycleId,
            'scheduled_for': _dateOnly(
              startsOn.add(
                Duration(
                  days:
                      (sessionIndex ~/ weeklyOffsets.length) * 7 +
                      weeklyOffsets[sessionIndex % weeklyOffsets.length],
                ),
              ),
            ),
            'status': 'planned',
          });
          for (var sequence = 0; sequence < generated.sets.length; sequence++) {
            final set = generated.sets[sequence];
            await transaction.insert('training_sets', {
              'id': '$sessionId-s$sequence',
              'session_id': sessionId,
              'lift_id': lift.name,
              'sequence': sequence,
              'kind': set.kind.name,
              'training_max': set.trainingMax,
              'percentage': set.percentage,
              'unrounded_load': set.unroundedLoad,
              'rounding_increment': set.roundingIncrement,
              'prescribed_load': set.load,
              'prescribed_reps': set.repetitions,
              'performance_set': set.isPerformanceSet ? 1 : 0,
            });
          }
          sessionIndex++;
        }
      }
    });
  }

  @override
  Future<TrainingSnapshot> loadSnapshot() async {
    final database = await localDatabase.open();
    final profiles = await database.query(
      'athlete_profiles',
      where: 'deleted_at IS NULL',
      limit: 1,
    );
    if (profiles.isEmpty) throw StateError('No local profile exists.');
    final unit = profiles.single['preferred_unit'] == 'lb'
        ? WeightUnit.pounds
        : WeightUnit.kilograms;
    final planned = await database.query(
      'training_sessions',
      where: "status != 'complete'",
      orderBy: 'scheduled_for, id',
      limit: 1,
    );
    final historyRows = await database.query(
      'training_sessions',
      where: "status = 'complete'",
      orderBy: 'completed_at DESC',
    );
    final maxRows = await database.rawQuery(
      '''SELECT tm.exercise_id, tm.training_max
         FROM training_max_history tm
         JOIN (
           SELECT exercise_id, MAX(effective_at) AS effective_at
           FROM training_max_history
           GROUP BY exercise_id
         ) latest ON latest.exercise_id = tm.exercise_id
                 AND latest.effective_at = tm.effective_at''',
    );
    final programRows = await database.rawQuery(
      '''SELECT pd.id, pd.schema_version, pd.definition_json
         FROM training_cycles c
         JOIN program_definitions pd ON pd.id = c.program_definition_id
         WHERE c.status = 'active'
         ORDER BY c.created_at DESC
         LIMIT 1''',
    );
    if (programRows.isEmpty) throw StateError('No active program exists.');
    final programRow = programRows.single;
    final definition = jsonDecode(programRow['definition_json']! as String);
    if (definition is! Map<String, Object?>) {
      throw const FormatException('Invalid program definition JSON.');
    }
    return TrainingSnapshot(
      displayName: profiles.single['display_name']! as String,
      nextSession: planned.isEmpty
          ? null
          : await _session(database, planned.single, unit),
      history: [
        for (final row in historyRows) await _session(database, row, unit),
      ],
      trainingMaxes: {
        for (final row in maxRows)
          MainLift.values.byName(row['exercise_id']! as String):
              (row['training_max']! as num).toDouble(),
      },
      activeProgram: ProgramDefinitionRef.fromJson(
        definition,
        persistentId: programRow['id']! as String,
        persistentVersion: programRow['schema_version']! as int,
      ),
    );
  }

  @override
  Future<void> updateTrainingMaxes(Map<MainLift, double> trainingMaxes) async {
    if (trainingMaxes.length != MainLift.values.length ||
        trainingMaxes.values.any((value) => value <= 0)) {
      throw ArgumentError('Four positive training maxes are required.');
    }
    final database = await localDatabase.open();
    final profiles = await database.query('athlete_profiles', limit: 1);
    if (profiles.isEmpty) throw StateError('No local profile exists.');
    final profile = profiles.single;
    final unit = profile['preferred_unit']! as String;
    final increment = (profile['rounding_increment']! as num).toDouble();
    final rounder = LoadRounder(increment: increment);
    final now = _clock().toUtc();
    await database.transaction((transaction) async {
      for (final entry in trainingMaxes.entries) {
        await transaction.insert('training_max_history', {
          'id': 'tm-edit-${entry.key.name}-${now.microsecondsSinceEpoch}',
          'athlete_id': _athleteId,
          'exercise_id': entry.key.name,
          'one_rep_max': entry.value / 0.9,
          'training_max': entry.value,
          'unit': unit,
          'effective_at': now.toIso8601String(),
        });
        final futureSets = await transaction.rawQuery(
          '''SELECT ts.id, ts.percentage
             FROM training_sets ts
             JOIN training_sessions s ON s.id = ts.session_id
             WHERE ts.lift_id = ? AND ts.result IS NULL
               AND s.status != 'complete' ''',
          [entry.key.name],
        );
        for (final set in futureSets) {
          final percentage = (set['percentage']! as num).toDouble();
          final unrounded = entry.value * percentage;
          final updated = await transaction.update(
            'training_sets',
            {
              'training_max': entry.value,
              'unrounded_load': unrounded,
              'prescribed_load': rounder.nearest(unrounded),
            },
            where: 'id = ?',
            whereArgs: [set['id']],
          );
          if (updated != 1) {
            throw StateError('Set not found while updating Training Max.');
          }
        }
      }
    });
  }

  Future<StoredSession> _session(
    Database database,
    Map<String, Object?> row,
    WeightUnit unit,
  ) async {
    final setRows = await database.query(
      'training_sets',
      where: 'session_id = ?',
      whereArgs: [row['id']],
      orderBy: 'sequence',
    );
    final lift = MainLift.values.byName(setRows.first['lift_id']! as String);
    final restRows = await database.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['rest_until:${row['id']}'],
      limit: 1,
    );
    return StoredSession(
      id: row['id']! as String,
      lift: lift,
      scheduledFor: DateTime.parse(row['scheduled_for']! as String),
      unit: unit,
      isComplete: row['status'] == 'complete',
      notes: row['notes']! as String,
      startedAt: row['started_at'] == null
          ? null
          : DateTime.parse(row['started_at']! as String),
      restUntil: restRows.isEmpty
          ? null
          : DateTime.tryParse(restRows.single['value']! as String),
      sets: [
        for (final set in setRows)
          StoredSet(
            id: set['id']! as String,
            sequence: set['sequence']! as int,
            kind: SetKind.values.byName(set['kind']! as String),
            load: (set['prescribed_load']! as num).toDouble(),
            repetitions: set['prescribed_reps']! as int,
            isPerformanceSet: set['performance_set'] == 1,
            isComplete: set['result'] != null,
            completedRepetitions: set['completed_reps'] as int?,
            result: set['result'] == null
                ? null
                : SetResult.values.byName(set['result']! as String),
          ),
      ],
    );
  }

  @override
  Future<void> completeSet(String setId, {required int repetitions}) async {
    await recordSet(setId, repetitions: repetitions, result: SetResult.success);
  }

  @override
  Future<void> recordSet(
    String setId, {
    required int repetitions,
    required SetResult result,
  }) async {
    if (repetitions < 0) throw ArgumentError.value(repetitions);
    final database = await localDatabase.open();
    await database.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        '''SELECT ts.lift_id, ts.prescribed_load, ts.performance_set, s.status,
                  ap.preferred_unit
           FROM training_sets ts
           JOIN training_sessions s ON s.id = ts.session_id
           JOIN training_cycles c ON c.id = s.cycle_id
           JOIN athlete_profiles ap ON ap.id = c.athlete_id
           WHERE ts.id = ?''',
        [setId],
      );
      if (rows.isEmpty) throw StateError('Set not found: $setId');
      if (rows.single['status'] == 'complete') {
        throw StateError('Session is already complete for set: $setId');
      }
      final updated = await transaction.update(
        'training_sets',
        {'result': result.name, 'completed_reps': repetitions},
        where: 'id = ?',
        whereArgs: [setId],
      );
      if (updated != 1) throw StateError('Set not found: $setId');
      final row = rows.single;
      if (result != SetResult.success ||
          repetitions == 0 ||
          row['performance_set'] != 1) {
        return;
      }
      final liftId = row['lift_id']! as String;
      final unit = row['preferred_unit']! as String;
      final load = (row['prescribed_load']! as num).toDouble();
      const calculator = MaxCalculator();
      final estimate = calculator.estimateOneRepMax(
        load: load,
        repetitions: repetitions,
      );
      final previous = await transaction.query(
        'personal_records',
        where: 'lift_id = ? AND unit = ?',
        whereArgs: [liftId, unit],
      );
      final previousBest = previous.fold<double>(0, (best, record) {
        final candidate = calculator.estimateOneRepMax(
          load: (record['load']! as num).toDouble(),
          repetitions: record['repetitions']! as int,
        );
        return candidate > best ? candidate : best;
      });
      if (estimate > previousBest) {
        await transaction.insert('personal_records', {
          'id': 'pr-${_clock().microsecondsSinceEpoch}-$setId',
          'lift_id': liftId,
          'load': load,
          'repetitions': repetitions,
          'unit': unit,
          'achieved_at': _clock().toUtc().toIso8601String(),
          'source_set_id': setId,
        });
      }
    });
  }

  @override
  Future<void> startSession(String sessionId) async {
    final database = await localDatabase.open();
    final updated = await database.update(
      'training_sessions',
      {'status': 'started', 'started_at': _clock().toUtc().toIso8601String()},
      where: "id = ? AND status = 'planned'",
      whereArgs: [sessionId],
    );
    if (updated != 1) {
      throw StateError('Planned session not found: $sessionId');
    }
  }

  @override
  Future<void> setRestUntil(String sessionId, DateTime? restUntil) async {
    final database = await localDatabase.open();
    final sessions = await database.query(
      'training_sessions',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (sessions.isEmpty) throw StateError('Session not found: $sessionId');
    final key = 'rest_until:$sessionId';
    if (restUntil == null) {
      await database.delete('app_metadata', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await database.insert('app_metadata', {
      'key': key,
      'value': restUntil.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> finishSession(String sessionId) async {
    final database = await localDatabase.open();
    await database.transaction((transaction) async {
      final sessions = await transaction.query(
        'training_sessions',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty) throw StateError('Session not found: $sessionId');
      if (sessions.single['status'] == 'complete') {
        throw StateError('Session is already complete: $sessionId');
      }
      final incomplete = Sqflite.firstIntValue(
        await transaction.rawQuery(
          'SELECT COUNT(*) FROM training_sets WHERE session_id = ? AND result IS NULL',
          [sessionId],
        ),
      );
      if ((incomplete ?? 0) != 0) {
        throw StateError('Session has incomplete sets: $sessionId');
      }
      final updated = await transaction.update(
        'training_sessions',
        {
          'status': 'complete',
          'completed_at': _clock().toUtc().toIso8601String(),
        },
        where: "id = ? AND status != 'complete'",
        whereArgs: [sessionId],
      );
      if (updated != 1) throw StateError('Session not found: $sessionId');
      await transaction.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['rest_until:$sessionId'],
      );
    });
  }

  @override
  Future<void> updateSessionNotes(String sessionId, String notes) async {
    final database = await localDatabase.open();
    final updated = await database.update(
      'training_sessions',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (updated != 1) throw StateError('Session not found: $sessionId');
  }

  @override
  Future<void> close() => localDatabase.close();

  @override
  Future<String> exportBackup() =>
      _backupManager.exportBackup(appVersion: '0.1.0');

  @override
  Future<ImportReport> importBackup(String source, {required bool dryRun}) =>
      _backupManager.importBackup(source, dryRun: dryRun);

  @override
  Future<void> deleteAllData() => _backupManager.deleteAllData();

  String _dateOnly(DateTime date) => date.toIso8601String().substring(0, 10);
}
