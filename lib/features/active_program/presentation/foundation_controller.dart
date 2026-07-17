import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';

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
      state = FoundationState.error;
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      error = null;
    } catch (caught) {
      error = caught;
      state = FoundationState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(store.close());
    super.dispose();
  }
}
