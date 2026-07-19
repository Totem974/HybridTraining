import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> generate(
    WidgetTester tester,
    Map<String, Object?> configuration,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Poc531GeneratorPage(
          core: const DomainPoc531GeneratorCore(),
          initialConfiguration: configuration,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-json')), findsOneWidget);
    expect(find.textContaining('Cycle'), findsWidgets);
  }

  const lifts = <String, double>{
    'Press': 60,
    'Bench Press': 90,
    'Squat': 120,
    'Deadlift': 150,
  };

  testWidgets('Original calculator scenario', (tester) async {
    await generate(tester, const {
      'mode': 'classic',
      'programId': 'simplestStrength',
      'lifts': lifts,
      'days': 4,
    });
  });

  testWidgets('Beyond calculator scenario', (tester) async {
    await generate(tester, const {
      'mode': 'classic',
      'programId': 'boringButBig',
      'lifts': lifts,
      'days': 4,
    });
  });

  testWidgets('Forever calculator scenario', (tester) async {
    await generate(tester, const {
      'mode': 'forever',
      'foreverTemplateId': 'FV-236',
      'lifts': lifts,
      'days': 4,
    });
  });
}
