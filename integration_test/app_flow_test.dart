import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_shell.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Beginner core runs, resumes, reports, previews and restores', (
    tester,
  ) async {
    await _open(tester, AppEnvironment.dev);
    expect(find.byKey(const Key('core-validation-shell')), findsOneWidget);
    expect(find.byKey(const Key('dev-validation-banner')), findsOneWidget);

    await _deleteAll(tester);
    await tester.tap(find.byKey(const Key('destination-engine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-dev-fixture')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-plan-count')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('switch-start-date')),
      '2026-08-03',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final preview = find.byKey(const Key('preview-program-switch'));
    await tester.ensureVisible(preview);
    expect(tester.widget<FilledButton>(preview).onPressed, isNotNull);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    final previewShell = tester.widget<CoreValidationShell>(
      find.byType(CoreValidationShell),
    );
    expect(
      previewShell.controller.lastError,
      isNull,
      reason: 'Program switch preview failed on Android',
    );
    expect(previewShell.controller.programSwitchPreview, isNotNull);

    final start = find.byKey(const Key('start-workout'));
    await _tapEngine(tester, start);
    await tester.pumpAndSettle();
    await _record(tester, success: true, repetitions: '6', load: '42.5');

    final pause = find.byKey(const Key('pause-resume-workout'));
    await _tapEngine(tester, pause);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CoreValidationShell>(find.byType(CoreValidationShell))
          .controller
          .workout
          ?.state
          .name,
      'paused',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _open(tester, AppEnvironment.dev);
    expect(
      tester
          .widget<CoreValidationShell>(find.byType(CoreValidationShell))
          .controller
          .workout
          ?.state
          .name,
      'paused',
    );
    final resume = find.byKey(const Key('pause-resume-workout'));
    await _tapEngine(tester, resume);
    await tester.pumpAndSettle();
    await _record(tester, success: false, repetitions: '3', load: '50');

    var shell = tester.widget<CoreValidationShell>(
      find.byType(CoreValidationShell),
    );
    while (shell.controller.workout!.completedSets <
        shell.controller.workout!.totalSets) {
      final skip = find.byKey(const Key('record-skip'));
      await _tapEngine(tester, skip);
      await tester.pumpAndSettle();
      shell = tester.widget<CoreValidationShell>(
        find.byType(CoreValidationShell),
      );
    }
    final complete = find.byKey(const Key('complete-workout'));
    await _tapEngine(tester, complete);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('destination-tracking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actual-tonnage')), findsOneWidget);
    expect(find.textContaining('405'), findsOneWidget);

    await tester.tap(find.byKey(const Key('destination-engine')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('switch-start-date')),
      '2026-08-03',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _tapEngine(tester, find.byKey(const Key('preview-program-switch')));
    await tester.pumpAndSettle();
    final switchShell = tester.widget<CoreValidationShell>(
      find.byType(CoreValidationShell),
    );
    await switchShell.controller.applyProgramSwitch(
      DateTime.utc(2026, 8, 3),
      abandonActiveSession: false,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CoreValidationShell>(find.byType(CoreValidationShell))
          .controller
          .lastError,
      isNull,
    );
    final workoutDate = find.byKey(const Key('workout-date'));
    await tester.ensureVisible(workoutDate);
    await tester.enterText(workoutDate, '2026-08-04');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _tapEngine(tester, find.byKey(const Key('reschedule-workout')));
    await tester.pumpAndSettle();
    await _tapEngine(tester, find.byKey(const Key('skip-workout')));
    await tester.pumpAndSettle();
    await _tapEngine(tester, find.byKey(const Key('start-workout')));
    await tester.pumpAndSettle();
    await _tapEngine(tester, find.byKey(const Key('abandon-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-abandon-workout')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();
    final export = find.byKey(const Key('export-backup'));
    await tester.ensureVisible(export);
    await tester.tap(export);
    await tester.pumpAndSettle();
    final backupShell = tester.widget<CoreValidationShell>(
      find.byType(CoreValidationShell),
    );
    final backup = backupShell.controller.exportedBackup;
    expect(backup, isNotNull);
    final source = find.byKey(const Key('import-source'));
    await tester.ensureVisible(source);
    await tester.enterText(source, backup!);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final simulate = find.byKey(const Key('simulate-import'));
    await tester.ensureVisible(simulate);
    await tester.tap(simulate);
    await tester.pumpAndSettle();
    final apply = find.byKey(const Key('apply-import'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-report-status')), findsOneWidget);

    await _deleteAll(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _open(tester, AppEnvironment.prod);
    expect(find.byKey(const Key('dev-validation-banner')), findsNothing);
    expect(find.byKey(const Key('create-dev-fixture')), findsNothing);
    expect(find.byKey(const Key('prod-no-demo')), findsOneWidget);
  });
}

Future<void> _open(WidgetTester tester, AppEnvironment environment) async {
  await tester.pumpWidget(HybridTrainingApp(environment: environment));
  await tester.pumpAndSettle();
}

Future<void> _record(
  WidgetTester tester, {
  required bool success,
  required String repetitions,
  required String load,
}) async {
  final reps = find.byKey(const Key('actual-repetitions'));
  await tester.ensureVisible(reps);
  await tester.enterText(reps, repetitions);
  await tester.enterText(find.byKey(const Key('actual-load')), load);
  await tester.enterText(find.byKey(const Key('actual-rpe')), '8');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final action = find.byKey(Key(success ? 'record-success' : 'record-failure'));
  await _tapEngine(tester, action);
  await tester.pumpAndSettle();
}

Future<void> _deleteAll(WidgetTester tester) async {
  final settings = find.byKey(const Key('destination-settings'));
  await tester.tap(settings);
  await tester.pumpAndSettle();
  final delete = find.byKey(const Key('delete-all-data'));
  await tester.ensureVisible(delete);
  await tester.tap(delete);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-delete-data')));
  await tester.pumpAndSettle();
}

Finder _engineScrollable() => find
    .descendant(
      of: find.byKey(const Key('engine-panel')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapEngine(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: _engineScrollable());
  for (var attempt = 0; attempt < 6; attempt++) {
    final hit = finder.hitTestable();
    if (hit.evaluate().isNotEmpty) {
      await tester.tap(hit);
      return;
    }
    await tester.drag(
      find.byKey(const Key('engine-panel')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}
