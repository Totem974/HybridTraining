import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';

void main() {
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
}
