import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

void main() {
  testWidgets('creates a local profile and displays the first session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeTrainingStore();
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.dev, store: store),
    );
    await tester.pumpAndSettle();

    expect(find.text('Introduction'), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const Key('continue')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Charge maximum'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Camille');
    for (final lift in MainLift.values) {
      await tester.enterText(find.byKey(Key('max-${lift.name}')), '100');
    }
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.byKey(const Key('continue')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('create-cycle')));
    await tester.pumpAndSettle();

    expect(store.created?.displayName, 'Camille');
    expect(store.created?.oneRepMaxes, hasLength(4));
    expect(find.byKey(const Key('home-dashboard')), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Statistiques'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Profil'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    expect(find.text('Réglages'), findsWidgets);
    await tester.tap(find.text('Gérer mon programme'));
    await tester.pumpAndSettle();
    expect(find.text('Bibliothèque'), findsOneWidget);
    await tester.tap(find.text('Original 5/3/1 + First Set Last'));
    await tester.pumpAndSettle();
    expect(find.text('Programme actuel'), findsOneWidget);
  });

  testWidgets('records a set, finishes a session and shows history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeTrainingStore(hasExistingProfile: true);
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.prod, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rien à signaler');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.ensureVisible(find.byKey(const Key('complete-current-set')));
    await tester.tap(find.byKey(const Key('complete-current-set')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('finish-session')));
    await tester.tap(find.byKey(const Key('finish-session')));
    await tester.pumpAndSettle();

    expect(store.completedSetIds, ['set-1']);
    expect(store.finishedSessionIds, ['session-1']);
    expect(store.savedNotes, ['Rien à signaler', 'Rien à signaler']);
    expect(find.text('Aucune séance planifiée.'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(tester.widgetList(find.byType(Banner)), isEmpty);
  });
}

class _FakeTrainingStore implements TrainingStore {
  _FakeTrainingStore({bool hasExistingProfile = false})
    : _hasProfile = hasExistingProfile;

  bool _hasProfile;
  bool _setComplete = false;
  bool _sessionComplete = false;
  FoundationProfileInput? created;
  final completedSetIds = <String>[];
  final finishedSessionIds = <String>[];
  final savedNotes = <String>[];

  StoredSession get _session => StoredSession(
    id: 'session-1',
    lift: MainLift.squat,
    scheduledFor: DateTime(2026, 7, 17),
    unit: WeightUnit.kilograms,
    sets: [
      StoredSet(
        id: 'set-1',
        sequence: 0,
        kind: SetKind.main,
        load: 90,
        repetitions: 3,
        isPerformanceSet: true,
        isComplete: _setComplete,
      ),
    ],
    isComplete: _sessionComplete,
    notes: '',
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasProfile() async => _hasProfile;

  @override
  Future<void> createFoundation(FoundationProfileInput input) async {
    created = input;
    _hasProfile = true;
  }

  @override
  Future<TrainingSnapshot> loadSnapshot() async => TrainingSnapshot(
    displayName: created?.displayName ?? 'Camille',
    nextSession: _sessionComplete ? null : _session,
    history: _sessionComplete ? [_session] : [],
  );

  @override
  Future<void> completeSet(String setId, {required int repetitions}) async {
    completedSetIds.add(setId);
    _setComplete = true;
  }

  @override
  Future<void> startSession(String sessionId) async {}

  @override
  Future<void> recordSet(
    String setId, {
    required int repetitions,
    required SetResult result,
  }) async {
    completedSetIds.add(setId);
    _setComplete = true;
  }

  @override
  Future<void> setRestUntil(String sessionId, DateTime? restUntil) async {}

  @override
  Future<void> finishSession(String sessionId) async {
    finishedSessionIds.add(sessionId);
    _sessionComplete = true;
  }

  @override
  Future<void> updateSessionNotes(String sessionId, String notes) async {
    savedNotes.add(notes);
  }

  @override
  Future<void> close() async {}
}
