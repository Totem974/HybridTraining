import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';

void main() {
  testWidgets('web POC mode starts without constructing SQLite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HybridTrainingApp(
        environment: AppEnvironment.dev,
        pocOnlyMode: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poc-531-landing')), findsOneWidget);
  });

  testWidgets('isolated landing routes to onboarding and generator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: '/poc/531', onGenerateRoute: buildPoc531Route),
    );
    expect(find.byKey(const Key('poc-531-landing')), findsOneWidget);

    await tester.tap(find.text('Ouvrir l’onboarding'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poc-531-onboarding')), findsOneWidget);

    Navigator.of(tester.element(find.byType(Scaffold))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir le générateur'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
  });

  testWidgets('direct Forever program route derives its generation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/poc/531/program/FV-236',
        onGenerateRoute: buildPoc531Route,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
    final generation = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('generation')),
    );
    expect(generation.initialValue, 'forever');
  });
}
