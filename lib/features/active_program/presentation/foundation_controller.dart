import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

enum FoundationState { loading, onboarding, ready, error }

class FoundationController extends ChangeNotifier {
  FoundationController(this.store);

  final TrainingStore store;
  FoundationState state = FoundationState.loading;
  TrainingSnapshot? snapshot;
  Object? error;

  Future<void> initialize() async {
    try {
      await store.initialize();
      if (await store.hasProfile()) {
        snapshot = await store.loadSnapshot();
        state = FoundationState.ready;
      } else {
        state = FoundationState.onboarding;
      }
    } catch (caught) {
      error = caught;
      state = FoundationState.error;
    }
    notifyListeners();
  }

  Future<void> createProfile(FoundationProfileInput input) async {
    await _run(() async {
      await store.createFoundation(input);
      snapshot = await store.loadSnapshot();
      state = FoundationState.ready;
    });
  }

  Future<void> completeSet(String id, int repetitions) async {
    await _run(() async {
      await store.completeSet(id, repetitions: repetitions);
      snapshot = await store.loadSnapshot();
    });
  }

  Future<void> startSession(String id) async {
    await _run(() async {
      await store.startSession(id);
      snapshot = await store.loadSnapshot();
    });
  }

  Future<void> recordSet(String id, int repetitions, SetResult result) async {
    await _run(() async {
      await store.recordSet(id, repetitions: repetitions, result: result);
      snapshot = await store.loadSnapshot();
    });
  }

  Future<void> setRestUntil(String id, DateTime? restUntil) async {
    await store.setRestUntil(id, restUntil);
  }

  Future<void> updateTrainingMaxes(Map<MainLift, double> trainingMaxes) async {
    await _run(() async {
      await store.updateTrainingMaxes(trainingMaxes);
      snapshot = await store.loadSnapshot();
    });
  }

  Future<String> exportBackup() => store.exportBackup();

  Future<ImportReport> importBackup(
    String source, {
    required bool dryRun,
  }) async {
    final report = await store.importBackup(source, dryRun: dryRun);
    if (report.applied) await initialize();
    return report;
  }

  Future<void> deleteAllData() async {
    await store.deleteAllData();
    await store.initialize();
    snapshot = null;
    state = FoundationState.onboarding;
    notifyListeners();
  }

  Future<void> finishSession(String id) async {
    await _run(() async {
      await store.finishSession(id);
      snapshot = await store.loadSnapshot();
    });
  }

  Future<void> updateSessionNotes(String id, String notes) async {
    try {
      await store.updateSessionNotes(id, notes);
      error = null;
    } catch (caught) {
      error = caught;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      error = null;
    } catch (caught) {
      error = caught;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(store.close());
    super.dispose();
  }
}
