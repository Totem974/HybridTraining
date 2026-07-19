import 'package:flutter/foundation.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/domain/core_validation_snapshot.dart';

enum CoreValidationState { loading, ready, error }

class CoreValidationController extends ChangeNotifier {
  CoreValidationController(this.repository);

  final CoreValidationRepository repository;
  CoreValidationState state = CoreValidationState.loading;
  CoreValidationSnapshot snapshot = const CoreValidationSnapshot.empty();
  Object? lastError;
  String? exportedBackup;
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

  Future<void> deleteAllData() async {
    await _run(() async {
      await repository.deleteAllData();
      exportedBackup = null;
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
