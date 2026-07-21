import 'package:sqflite/sqflite.dart';

import 'training_plan_snapshot_repository.dart';
import 'training_plan_status_repository.dart';

/// Runtime facade for training.db.
///
/// Plan rows carry reproducibility attestations and can only be created through
/// [createPlan]. Raw SQL, batches and caller-controlled transactions are not
/// exposed because each would leak the underlying executor and bypass that
/// boundary. Structured writes remain available for non-plan runtime tables.
final class TrainingDatabase implements Database {
  TrainingDatabase._(this._database);

  static Future<TrainingDatabase> open({
    required String path,
    required DatabaseFactory factory,
    required OpenDatabaseOptions options,
  }) async =>
      TrainingDatabase._(await factory.openDatabase(path, options: options));

  final Database _database;

  Future<void> createPlan(TrainingPlanSnapshotWrite write) =>
      const TrainingPlanSnapshotRepository().create(_database, write);

  Future<void> transitionPlanStatus({
    required String planId,
    required TrainingPlanStatus to,
  }) => const TrainingPlanStatusRepository().transition(
    _database,
    planId: planId,
    to: to,
  );

  @override
  String get path => _database.path;

  @override
  bool get isOpen => _database.isOpen;

  @override
  Future<void> close() => _database.close();

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _database.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    if (!RegExp(r'^\s*select\b', caseSensitive: false).hasMatch(sql) ||
        sql.contains(';')) {
      throw const TrainingSnapshotWriteException(
        'database.raw_query_forbidden',
      );
    }
    return _database.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _requireMutableTable(table);
    return _database.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _requireMutableTable(table);
    return _database.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _requireMutableTable(table);
    return _database.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async =>
      throw const TrainingSnapshotWriteException(
        'database.raw_write_forbidden',
      );

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async =>
      throw const TrainingSnapshotWriteException(
        'database.raw_write_forbidden',
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async =>
      throw const TrainingSnapshotWriteException(
        'database.raw_write_forbidden',
      );

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async =>
      throw const TrainingSnapshotWriteException(
        'database.raw_write_forbidden',
      );

  @override
  Batch batch() => throw const TrainingSnapshotWriteException(
    'database.raw_write_forbidden',
  );

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction transaction) action, {
    bool? exclusive,
  }) async => throw const TrainingSnapshotWriteException(
    'database.raw_write_forbidden',
  );

  void _requireMutableTable(String table) {
    if (table == 'plans') {
      throw const TrainingSnapshotWriteException(
        'snapshot.direct_write_forbidden',
      );
    }
    if (!_mutableTables.contains(table) ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(table)) {
      throw const TrainingSnapshotWriteException(
        'database.table_write_forbidden',
      );
    }
  }

  // Database methods intentionally not surfaced by the runtime facade fail
  // closed rather than forwarding an executor that could mutate plan rows.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const TrainingSnapshotWriteException(
        'database.operation_forbidden',
      );
}

const _mutableTables = <String>{
  'sessions',
  'session_blocks',
  'set_prescriptions',
  'set_results',
  'training_events',
  'plan_statistics',
};
