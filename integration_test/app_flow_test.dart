import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Core Validation Shell persists the DEV Beginner plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HybridTrainingApp(environment: AppEnvironment.dev),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('core-validation-shell')), findsOneWidget);
    expect(find.byKey(const Key('dev-validation-banner')), findsOneWidget);

    final fixtureButton = find.byKey(const Key('create-dev-fixture'));
    if (fixtureButton.evaluate().isNotEmpty) {
      await tester.tap(fixtureButton);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('active-plan-count')), findsOneWidget);
    expect(find.byKey(const Key('planned-session-count')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      const HybridTrainingApp(environment: AppEnvironment.dev),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('active-plan-count')), findsOneWidget);
    await tester.tap(find.byKey(const Key('destination-tracking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actual-tonnage')), findsOneWidget);
    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-backup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-ready')), findsOneWidget);
  });
}
