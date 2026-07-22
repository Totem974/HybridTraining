import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/storage/sqlite_database_file.dart';
import '../../cycle_generation/domain/cycle_contract.dart';
import '../application/cycle_web_contract.dart';
import '../application/cycle_web_draft_repository.dart';

final class SqliteCycleWebDraftRepository implements CycleWebDraftRepository {
  const SqliteCycleWebDraftRepository({
    required this.databaseFile,
    required this.draftId,
    required this.profileId,
    required this.now,
  });

  final SqliteDatabaseFile databaseFile;
  final String draftId;
  final String profileId;
  final DateTime Function() now;

  @override
  Future<CycleEditorState?> load() async {
    final db = await databaseFile.open();
    final rows = await db.query(
      'generation_drafts',
      columns: ['request_json'],
      where: 'id = ? AND profile_id = ?',
      whereArgs: [draftId, profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final root = jsonDecode(rows.single['request_json']! as String);
    if (root is! Map<String, Object?> ||
        root.keys.toSet().difference({
          'schemaVersion',
          'templateId',
          'variantId',
          'values',
          'request',
        }).isNotEmpty ||
        (root['schemaVersion'] != 1 && root['schemaVersion'] != 2) ||
        root['templateId'] is! String ||
        root['variantId'] is! String ||
        root['values'] is! Map<String, Object?>) {
      throw const FormatException('Invalid Cycle Web draft.');
    }
    final values = root['values']! as Map<String, Object?>;
    if (values.values.any((value) => value == null || !_isJsonValue(value))) {
      throw const FormatException('Invalid Cycle Web option value.');
    }
    final request = root['request'];
    if (request != null && request is! Map<String, Object?>) {
      throw const FormatException('Invalid Cycle Web request draft.');
    }
    final requestMap = request as Map<String, Object?>?;
    return CycleEditorState(
      templateId: root['templateId']! as String,
      variantId: root['variantId']! as String,
      values: values.cast<String, Object>(),
      startDate: requestMap?['startDate'] == null
          ? null
          : DateTime.parse(requestMap!['startDate']! as String),
      trainingDays: _intList(requestMap?['trainingDays']),
      sessionOrder: _stringList(requestMap?['sessionOrder']),
      maxInputs: _decodeMaxInputs(requestMap?['maxInputs']),
      globalTrainingMaxRatioBasisPoints:
          requestMap?['globalTrainingMaxRatioBasisPoints'] as int? ?? 9000,
      trainingMaxRatioByMovementBasisPoints: _intMap(
        requestMap?['trainingMaxRatioByMovementBasisPoints'],
      ),
      unit: requestMap?['unit'] == null
          ? WeightUnit.kg
          : WeightUnit.values.byName(requestMap!['unit']! as String),
      roundingIncrementCentiUnits:
          requestMap?['roundingIncrementCentiUnits'] as int? ?? 250,
      barWeightCentiUnits: requestMap?['barWeightCentiUnits'] as int? ?? 2000,
      platesPerSideCentiUnits: _intList(requestMap?['platesPerSideCentiUnits']),
      programTitle: requestMap?['programTitle'] as String? ?? '',
      showPlating: requestMap?['showPlating'] as bool? ?? true,
      cycleId: requestMap?['cycleId'] as String? ?? '',
    );
  }

  @override
  Future<void> save(CycleEditorState state) async {
    if (draftId.trim().isEmpty ||
        profileId.trim().isEmpty ||
        state.templateId.trim().isEmpty ||
        state.variantId.trim().isEmpty ||
        state.values.values.any((value) => !_isJsonValue(value))) {
      throw const FormatException('Invalid Cycle Web draft.');
    }
    final db = await databaseFile.open();
    await db.insert('generation_drafts', {
      'id': draftId,
      'profile_id': profileId,
      'request_json': jsonEncode({
        'schemaVersion': 2,
        'templateId': state.templateId,
        'variantId': state.variantId,
        'values': state.values,
        'request': {
          'startDate': state.startDate?.toIso8601String(),
          'trainingDays': state.trainingDays,
          'sessionOrder': state.sessionOrder,
          'maxInputs': state.maxInputs.map(
            (id, input) => MapEntry(id, {
              'kind': input.kind.name,
              'weightCentiUnits': input.weightCentiUnits,
              'repetitions': input.repetitions,
            }),
          ),
          'globalTrainingMaxRatioBasisPoints':
              state.globalTrainingMaxRatioBasisPoints,
          'trainingMaxRatioByMovementBasisPoints':
              state.trainingMaxRatioByMovementBasisPoints,
          'unit': state.unit.name,
          'roundingIncrementCentiUnits': state.roundingIncrementCentiUnits,
          'barWeightCentiUnits': state.barWeightCentiUnits,
          'platesPerSideCentiUnits': state.platesPerSideCentiUnits,
          'programTitle': state.programTitle,
          'showPlating': state.showPlating,
          'cycleId': state.cycleId,
        },
      }),
      'updated_at': now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static bool _isJsonValue(Object? value) =>
      value == null ||
      value is String ||
      value is num ||
      value is bool ||
      (value is List && value.every(_isJsonValue)) ||
      (value is Map<String, Object?> && value.values.every(_isJsonValue));

  static List<int> _intList(Object? value) =>
      value == null ? const [] : (value as List<Object?>).cast<int>();

  static List<String> _stringList(Object? value) =>
      value == null ? const [] : (value as List<Object?>).cast<String>();

  static Map<String, int> _intMap(Object? value) => value == null
      ? const {}
      : (value as Map<String, Object?>).cast<String, int>();

  static Map<String, CycleMovementMaxInput> _decodeMaxInputs(Object? value) {
    if (value == null) return const {};
    return (value as Map<String, Object?>).map((id, raw) {
      final input = raw as Map<String, Object?>;
      return MapEntry(
        id,
        CycleMovementMaxInput(
          kind: CycleMaxInputKind.values.byName(input['kind']! as String),
          weightCentiUnits: input['weightCentiUnits']! as int,
          repetitions: input['repetitions'] as int?,
        ),
      );
    });
  }
}
