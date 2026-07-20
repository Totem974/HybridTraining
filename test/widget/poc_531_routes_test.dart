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
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
  });

  testWidgets('root POC route opens the single calculator page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: '/poc/531', onGenerateRoute: buildPoc531Route),
    );
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
    expect(find.byKey(const Key('program')), findsOneWidget);
    expect(find.byKey(const Key('poc-531-onboarding')), findsNothing);
  });

  testWidgets('direct Forever program route opens calculator in Forever mode', (
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
    expect(find.text('Template Forever exécutable'), findsOneWidget);
    expect(find.textContaining('Leader'), findsWidgets);
  });

  testWidgets('generator restores Forever mode from the query string', (
    tester,
  ) async {
    final route = buildPoc531Route(
      const RouteSettings(name: '/poc/531/generator?mode=forever'),
    );
    expect(route, isNotNull);
    await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forever-timeline')), findsOneWidget);
    expect(find.text('Leaders, Anchors et macrocycles'), findsOneWidget);
  });
}
