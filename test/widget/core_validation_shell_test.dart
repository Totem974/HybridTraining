import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/active_program/application/program_switch.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/domain/core_validation_snapshot.dart';
import 'package:hybrid_training/features/core_validation/domain/core_workout_snapshot.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';

void main() {
  testWidgets('starts directly in the four-destination validation shell', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('core-validation-shell')), findsOneWidget);
    expect(find.byKey(const Key('dev-validation-banner')), findsOneWidget);
    expect(find.byKey(const Key('destination-engine')), findsOneWidget);
    expect(find.byKey(const Key('destination-tracking')), findsOneWidget);
    expect(find.byKey(const Key('destination-profile')), findsOneWidget);
    expect(find.byKey(const Key('destination-settings')), findsOneWidget);
  });

  testWidgets('DEV fixture creates only the reviewed Beginner plan', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-dev-fixture')));
    await tester.pumpAndSettle();

    expect(repository.fixtureCreated, isTrue);
    expect(find.text('Beginner Prep School'), findsOneWidget);
    expect(find.byKey(const Key('active-plan-count')), findsOneWidget);
  });

  testWidgets('program switch preview requires and uses a start date', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-dev-fixture')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('preview-program-switch'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('switch-start-date')),
      '2026-08-03',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.previewRequested, isTrue);
    final apply = find.byKey(const Key('apply-program-switch'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-program-switch')));
    await tester.pumpAndSettle();
    expect(repository.switchApplied, isTrue);
  });

  testWidgets('production exposes no fixture action or demo data', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.prod,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dev-validation-banner')), findsNothing);
    expect(find.byKey(const Key('create-dev-fixture')), findsNothing);
    expect(find.byKey(const Key('prod-no-demo')), findsOneWidget);
    expect(repository.fixtureCreated, isFalse);
  });

  testWidgets('tracking never invents tonnage from prescriptions', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.prod,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-tracking')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actual-tonnage')), findsOneWidget);
  });

  testWidgets('import requires a successful simulation before atomic apply', (
    tester,
  ) async {
    final repository = _FakeCoreRepository();
    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-import')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('import-source')),
      '{"backup":1}',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('simulate-import')));
    await tester.pumpAndSettle();

    expect(repository.importDryRuns, [true]);
    expect(find.byKey(const Key('import-report-status')), findsOneWidget);
    final apply = find.byKey(const Key('apply-import'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(repository.importDryRuns, [true, false]);
  });
}

class _FakeCoreRepository implements CoreValidationRepository {
  bool fixtureCreated = false;
  final List<bool> importDryRuns = [];
  bool previewRequested = false;
  bool switchApplied = false;

  @override
  Future<void> applyProgramSwitch(
    DateTime startDate, {
    required bool abandonActiveSession,
    required String previewId,
    required bool confirmed,
  }) async => switchApplied = true;

  @override
  Future<void> createDevelopmentFixture() async => fixtureCreated = true;

  @override
  Future<void> deleteAllData() async => fixtureCreated = false;

  @override
  Future<void> beginOrEndRest({required Duration duration}) async {}

  @override
  Future<void> completeWorkout() async {}

  @override
  Future<void> abandonWorkout() async {}

  @override
  Future<void> skipWorkout() async {}

  @override
  Future<void> rescheduleWorkout(DateTime date) async {}

  @override
  Future<String> exportBackup() async => '{}';

  @override
  Future<CoreWorkoutSnapshot?> loadFirstWorkout() async => null;

  @override
  Future<void> pauseOrResumeWorkout() async {}

  @override
  Future<ProgramSwitchPreview> previewProgramSwitch(DateTime startDate) async {
    previewRequested = true;
    return ProgramSwitchPreview(
      previewId: 'preview-1',
      currentPlanId: 'current',
      nextPlanId: 'next',
      currentBlueprintId: 'bps',
      nextBlueprintId: 'bps',
      completedSessionsPreserved: 0,
      plannedSessionsCancelled: 9,
      activeSessionIds: const [],
      nextStartDate: startDate,
    );
  }

  @override
  Future<void> recordCurrentSet({
    required SetOutcomeStatus status,
    int? actualRepetitions,
    double? actualLoad,
    double? rpe,
    String notes = '',
  }) async {}

  @override
  Future<void> startFirstWorkout() async {}

  @override
  Future<void> undoLastSet() async {}

  @override
  Future<ImportReport> importBackup(
    String source, {
    required bool dryRun,
  }) async {
    importDryRuns.add(dryRun);
    return ImportReport(
      dryRun: dryRun,
      applied: !dryRun,
      sourceFormat: 'hybrid-training-backup',
      issues: const [],
    );
  }

  @override
  Future<CoreValidationSnapshot> load() async => fixtureCreated
      ? const CoreValidationSnapshot(
          profileName: 'Athlete DEV',
          unit: 'kg',
          activePlans: 1,
          plannedSessions: 9,
          completedSessions: 0,
          successfulSets: 0,
          failedSets: 0,
          skippedSets: 0,
          actualTonnage: null,
        )
      : const CoreValidationSnapshot.empty();
}
