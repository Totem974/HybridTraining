import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/original_fsl_program.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:sqflite/sqflite.dart';

class SqliteTrainingStore implements TrainingStore {
  SqliteTrainingStore({required this.localDatabase, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _athleteId = 'local-athlete';
  static const _programId = 'forever-original-fsl-v1';

  final LocalDatabase localDatabase;
  final DateTime Function() _clock;

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
      'name_key': 'program.original_fsl',
      'definition_json': jsonEncode({
        'format': 'hybrid-training-program',
        'schemaVersion': 1,
        'id': _programId,
        'nameKey': 'program.original_fsl',
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
    final database = await localDatabase.open();
    final now = _clock().toUtc();
    final cycleId = 'cycle-${now.microsecondsSinceEpoch}';
    final unit = input.unit == WeightUnit.kilograms ? 'kg' : 'lb';
    final rounder = LoadRounder(increment: input.roundingIncrement);
    const program = OriginalFslProgram();

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
        'program_definition_id': _programId,
        'program_definition_version': 1,
        'starts_on': _dateOnly(now),
        'status': 'active',
        'settings_json': jsonEncode({
          'unit': unit,
          'roundingIncrement': input.roundingIncrement,
          'trainingMaxRatio': 0.9,
          'supplementalSets': 5,
        }),
        'created_at': now.toIso8601String(),
      });

      var sessionOffset = 0;
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
            'scheduled_for': _dateOnly(now.add(Duration(days: sessionOffset))),
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
          sessionOffset++;
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
    return TrainingSnapshot(
      displayName: profiles.single['display_name']! as String,
      nextSession: planned.isEmpty
          ? null
          : await _session(database, planned.single, unit),
      history: [
        for (final row in historyRows) await _session(database, row, unit),
      ],
    );
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
    return StoredSession(
      id: row['id']! as String,
      lift: lift,
      scheduledFor: DateTime.parse(row['scheduled_for']! as String),
      unit: unit,
      isComplete: row['status'] == 'complete',
      sets: [
        for (final set in setRows)
          StoredSet(
            id: set['id']! as String,
            sequence: set['sequence']! as int,
            kind: SetKind.values.byName(set['kind']! as String),
            load: (set['prescribed_load']! as num).toDouble(),
            repetitions: set['prescribed_reps']! as int,
            isPerformanceSet: set['performance_set'] == 1,
            isComplete: set['result'] == 'success',
          ),
      ],
    );
  }

  @override
  Future<void> completeSet(String setId, {required int repetitions}) async {
    if (repetitions < 0) throw ArgumentError.value(repetitions);
    final database = await localDatabase.open();
    await database.update(
      'training_sets',
      {'result': 'success', 'completed_reps': repetitions},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  @override
  Future<void> finishSession(String sessionId) async {
    final database = await localDatabase.open();
    await database.update(
      'training_sessions',
      {
        'status': 'complete',
        'completed_at': _clock().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> close() => localDatabase.close();

  String _dateOnly(DateTime date) => date.toIso8601String().substring(0, 10);
}
