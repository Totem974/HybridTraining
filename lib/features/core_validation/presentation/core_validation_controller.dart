import 'package:flutter/foundation.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/domain/core_validation_snapshot.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';

enum CoreValidationState { loading, ready, error }

class CoreValidationController extends ChangeNotifier {
  CoreValidationController(this.repository);

  final CoreValidationRepository repository;
  CoreValidationState state = CoreValidationState.loading;
  CoreValidationSnapshot snapshot = const CoreValidationSnapshot.empty();
  Object? lastError;
  String? exportedBackup;
  ImportReport? importReport;
  String? _simulatedImportSource;
  bool _disposed = false;

  Future<void> initialize() async {
    state = CoreValidationState.loading;
    notifyListeners();
    try {
      snapshot = await repository.load();
      if (_disposed) return;
      state = CoreValidationState.ready;
      lastError = null;
    } catch (error) {
      if (_disposed) return;
      state = CoreValidationState.error;
      lastError = error;
    }
    notifyListeners();
  }

  Future<void> createDevelopmentFixture() async {
    await _run(() async {
      await repository.createDevelopmentFixture();
      snapshot = await repository.load();
    });
  }

  Future<void> exportBackup() async {
    await _run(() async => exportedBackup = await repository.exportBackup());
  }

  bool get canApplyImport =>
      importReport?.dryRun == true &&
      importReport?.issues.every(
            (issue) => issue.severity != ImportSeverity.error,
          ) ==
          true &&
      _simulatedImportSource != null;

  Future<void> simulateImport(String source) async {
    await _run(() async {
      final report = await repository.importBackup(source, dryRun: true);
      importReport = report;
      _simulatedImportSource =
          report.issues.any((issue) => issue.severity == ImportSeverity.error)
          ? null
          : source;
    });
  }

  void clearImportSimulation() {
    importReport = null;
    _simulatedImportSource = null;
  }

  Future<void> applySimulatedImport() async {
    final source = _simulatedImportSource;
    if (source == null || !canApplyImport) {
      throw StateError('A successful import simulation is required.');
    }
    await _run(() async {
      importReport = await repository.importBackup(source, dryRun: false);
      _simulatedImportSource = null;
      snapshot = await repository.load();
    });
  }

  Future<void> deleteAllData() async {
    await _run(() async {
      await repository.deleteAllData();
      exportedBackup = null;
      importReport = null;
      _simulatedImportSource = null;
      snapshot = await repository.load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    state = CoreValidationState.loading;
    notifyListeners();
    try {
      await action();
      if (_disposed) return;
      state = CoreValidationState.ready;
      lastError = null;
    } catch (error) {
      if (_disposed) return;
      state = CoreValidationState.error;
      lastError = error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
