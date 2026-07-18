import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile to persisted history', (tester) async {
    const fileName = 'hybrid_training_integration.db';
    final path = '${await getDatabasesPath()}/$fileName';
    await deleteDatabase(path);
    addTearDown(() => deleteDatabase(path));

    final initialStore = SqliteTrainingStore(
      localDatabase: LocalDatabase(fileName: fileName),
    );
    await tester.pumpWidget(
      HybridTrainingApp(environment: AppEnvironment.dev, store: initialStore),
    );
    await tester.pumpAndSettle();
    expect(find.text('Introduction'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Programme'), findsOneWidget);
    expect(
      find.text('5/3/1 Forever — Original + First Set Last'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Planning'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Charge maximum'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('profile-name')), 'Test local');
    for (final lift in MainLift.values) {
      await tester.enterText(find.byKey(Key('max-${lift.name}')), '100');
    }
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Validation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('continue')));
    await tester.pumpAndSettle();
    expect(find.text('Votre plan'), findsOneWidget);
    expect(
      find.text('5/3/1 Forever — Original + First Set Last'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('create-cycle')));
    await _pumpUntilFound(tester, find.byKey(const Key('open-workout')));

    await tester.tap(find.byKey(const Key('open-workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-workout')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('record-set-0-success')),
    );

    for (var set = 0; set < 8; set++) {
      final record = find.byKey(Key('record-set-$set-success'));
      await tester.ensureVisible(record);
      await tester.tap(record);
      final next = set == 7
          ? find.byKey(const Key('finish-session'))
          : find.byKey(const Key('skip-rest'));
      await _pumpUntilFound(tester, next);
      if (set != 7) {
        await tester.tap(find.byKey(const Key('skip-rest')));
        await _pumpUntilFound(
          tester,
          find.byKey(Key('record-set-${set + 1}-success')),
        );
      }
    }
    await tester.ensureVisible(find.byKey(const Key('finish-session')));
    await tester.tap(find.byKey(const Key('finish-session')));
    await _pumpUntilFound(tester, find.byKey(const Key('home-dashboard')));

    await initialStore.close();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final reopened = SqliteTrainingStore(
      localDatabase: LocalDatabase(fileName: fileName),
    );
    await reopened.initialize();
    final restored = await reopened.loadSnapshot();
    await reopened.close();

    expect(restored.displayName, 'Test local');
    expect(restored.activeProgram.family, ProgramFamily.forever);
    expect(restored.activeProgram.templateId, 'forever-original-fsl-v1');
    expect(restored.history, hasLength(1));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}
