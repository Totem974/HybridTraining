import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/presentation/program_library_screen.dart';

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
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('5/3/1 Forever'), findsOneWidget);
    for (var step = 0; step < 2; step++) {
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
    expect(
      find.text('5/3/1 Forever — Original + First Set Last'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('create-cycle')));
    await tester.pumpAndSettle();

    expect(store.created?.displayName, 'Camille');
    expect(store.created?.oneRepMaxes, hasLength(4));
    expect(find.byKey(const Key('home-dashboard')), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('increase-squat')));
    await tester.tap(find.byKey(const Key('save-cycle-maxes')));
    await tester.pumpAndSettle();
    expect(store.updatedMaxes?[MainLift.squat], 92.5);
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
    await tester.tap(find.byKey(const Key('export-data')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-json')), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.ensureVisible(find.text('Gérer mon programme'));
    await tester.tap(find.text('Gérer mon programme'));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramLibraryScreen), findsOneWidget);
    await tester.tap(find.text('Original 5/3/1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('program-detail-list')), findsOneWidget);
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
    await tester.ensureVisible(find.byKey(const Key('record-set-0-success')));
    await tester.tap(find.byKey(const Key('record-set-0-success')));
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

  testWidgets('resumes a persisted active session without starting it again', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeTrainingStore(
      hasExistingProfile: true,
      sessionStarted: true,
    );
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.dev, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-workout')));
    await tester.pumpAndSettle();
    expect(find.text('Reprendre'), findsOneWidget);
    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(store.startedSessionIds, isEmpty);
  });

  testWidgets('simulates import and confirms complete data deletion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeTrainingStore(hasExistingProfile: true);
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.dev, store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('import-data')));
    await tester.tap(find.byKey(const Key('import-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('import-json')),
      '{"format":"hybrid-training-backup"}',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('simulate-import')));
    await tester.pumpAndSettle();
    expect(find.text('Sauvegarde valide'), findsOneWidget);
    await tester.tap(find.byKey(const Key('apply-import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-dashboard')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('delete-data')));
    await tester.tap(find.byKey(const Key('delete-data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-data')));
    await tester.pumpAndSettle();
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('failed set write keeps the set pending and allows retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _FakeTrainingStore(
      hasExistingProfile: true,
      failNextRecord: true,
    );
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.dev, store: store),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();

    final record = find.byKey(const Key('record-set-0-success'));
    await tester.tap(record);
    await tester.pumpAndSettle();

    expect(find.text('0/1 séries terminées'), findsOneWidget);
    expect(
      find.text('Enregistrement impossible. Vous pouvez réessayer.'),
      findsOneWidget,
    );
    expect(record, findsOneWidget);
    await tester.tap(record);
    await tester.pumpAndSettle();
    expect(find.text('1/1 séries terminées'), findsOneWidget);
  });
  testWidgets('library exposes all concepts and filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: ProgramLibraryScreen(
          mode: ProgramLibraryMode.select,
          selectedPresetId: 'forever-original-fsl-v1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Original 5/3/1'), findsOneWidget);
    expect(find.text('First Set Last'), findsOneWidget);
    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('program-library-list')), findsOneWidget);
    for (final id in [
      'boring-but-big',
      'joker-sets',
      'coffinworm',
      'krypteia',
    ]) {
      final card = find.byKey(Key('concept-$id'));
      await tester.scrollUntilVisible(card, 250);
      expect(card, findsOneWidget);
    }
  });

  testWidgets('onboarding opens the selectable program library', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        store: _FakeTrainingStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Standard'), findsNothing);
    expect(find.text('Full Body'), findsNothing);
    await tester.tap(find.byKey(const Key('view-current-programs')));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramLibraryScreen), findsOneWidget);
  });
}

class _FakeTrainingStore implements TrainingStore {
  _FakeTrainingStore({
    bool hasExistingProfile = false,
    this.failNextRecord = false,
    this.sessionStarted = false,
  }) : _hasProfile = hasExistingProfile;

  bool _hasProfile;
  bool _setComplete = false;
  bool _sessionComplete = false;
  bool failNextRecord;
  final bool sessionStarted;
  final startedSessionIds = <String>[];
  FoundationProfileInput? created;
  final completedSetIds = <String>[];
  final finishedSessionIds = <String>[];
  final savedNotes = <String>[];
  Map<MainLift, double>? updatedMaxes;

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
    startedAt: sessionStarted ? DateTime.utc(2026, 7, 17, 8) : null,
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
    trainingMaxes: const {
      MainLift.squat: 90,
      MainLift.benchPress: 80,
      MainLift.deadlift: 100,
      MainLift.overheadPress: 50,
    },
    activeProgram: ProgramDefinitionRef.originalFsl,
  );

  @override
  Future<void> completeSet(String setId, {required int repetitions}) async {
    completedSetIds.add(setId);
    _setComplete = true;
  }

  @override
  Future<void> startSession(String sessionId) async {
    startedSessionIds.add(sessionId);
  }

  @override
  Future<void> recordSet(
    String setId, {
    required int repetitions,
    required SetResult result,
  }) async {
    if (failNextRecord) {
      failNextRecord = false;
      throw StateError('simulated write failure');
    }
    completedSetIds.add(setId);
    _setComplete = true;
  }

  @override
  Future<void> setRestUntil(String sessionId, DateTime? restUntil) async {}

  @override
  Future<void> updateTrainingMaxes(Map<MainLift, double> trainingMaxes) async {
    updatedMaxes = {...trainingMaxes};
  }

  @override
  Future<String> exportBackup() async =>
      '{"format":"hybrid-training-backup","schemaVersion":1}';

  @override
  Future<ImportReport> importBackup(
    String source, {
    required bool dryRun,
  }) async => ImportReport(
    dryRun: dryRun,
    applied: !dryRun,
    sourceFormat: 'hybrid-training-backup',
    issues: const [],
  );

  @override
  Future<void> deleteAllData() async {
    _hasProfile = false;
  }

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
