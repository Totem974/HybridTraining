import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

void main() {
  Future<void> openCalculator(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Poc531GeneratorPage(core: DomainPoc531GeneratorCore()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('example generates a visible week and enables JSON export', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.ensureVisible(find.text('Charger un exemple'));
    await tester.tap(find.text('Charger un exemple'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-json')), findsOneWidget);
    expect(find.textContaining('Cycle'), findsWidgets);
  });

  testWidgets('calculator exposes the complete reference control groups', (
    tester,
  ) async {
    await openCalculator(tester);
    for (final heading in [
      'WEIGHT',
      'TEMPLATE',
      'ADDITIONAL OPTIONS',
      'PLATING & BARBELL',
      'SCHEDULING',
      'OUTPUT',
      'PROGRAM',
    ]) {
      expect(find.text(heading), findsOneWidget);
    }
    expect(find.text('Boring But Big'), findsOneWidget);
    expect(find.text('Add Joker Sets'), findsOneWidget);
    expect(find.text('Skip warm-up'), findsOneWidget);
  });

  testWidgets('rep-max mode displays repetitions for all four lifts', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.text('Rep Max'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reps-Press')), findsOneWidget);
    expect(find.byKey(const Key('reps-Bench Press')), findsOneWidget);
    expect(find.byKey(const Key('reps-Squat')), findsOneWidget);
    expect(find.byKey(const Key('reps-Deadlift')), findsOneWidget);
  });

  testWidgets('Forever switches to the reviewed Leader Anchor calculator', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.text('Forever'));
    await tester.pumpAndSettle();
    expect(find.text('Template Forever exécutable'), findsOneWidget);
    expect(find.textContaining('Leader'), findsWidgets);
  });
}
