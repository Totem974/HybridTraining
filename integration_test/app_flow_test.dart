import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile to persisted history', (tester) async {
    const fileName = 'hybrid_training_integration.db';
    final path = '${await getDatabasesPath()}/$fileName';
    await deleteDatabase(path);
    addTearDown(() => deleteDatabase(path));

    await tester.pumpWidget(
      HybridTrainingApp(
        environment: AppEnvironment.dev,
        store: SqliteTrainingStore(
          localDatabase: LocalDatabase(fileName: fileName),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'Test local');
    for (final lift in MainLift.values) {
      await tester.enterText(find.byKey(Key('max-${lift.name}')), '100');
    }
    await tester.ensureVisible(find.byKey(const Key('create-cycle')));
    await tester.tap(find.byKey(const Key('create-cycle')));
    await tester.pumpAndSettle();

    while (find.text('Fait').evaluate().isNotEmpty) {
      await tester.tap(find.text('Fait').first);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('finish-session')));
    await tester.drag(
      find.byKey(const Key('workout-session')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-session')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final reopened = SqliteTrainingStore(
      localDatabase: LocalDatabase(fileName: fileName),
    );
    await reopened.initialize();
    final restored = await reopened.loadSnapshot();
    await reopened.close();

    expect(restored.displayName, 'Test local');
    expect(restored.history, hasLength(1));
  });
}
