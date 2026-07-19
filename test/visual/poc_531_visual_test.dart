import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

void main() {
  testWidgets('captures desktop calculator state', (tester) async {
    await _viewport(tester, const Size(1200, 900));
    await _pumpGeneratedProgram(tester);
    await expectLater(
      find.byKey(const Key('poc-531-generator')),
      matchesGoldenFile('goldens/poc-531-generator-desktop.png'),
    );
  });

  testWidgets('captures mobile generator state without overflow', (
    tester,
  ) async {
    await _viewport(tester, const Size(390, 844));
    await _pumpGeneratedProgram(tester);
    await expectLater(
      find.byKey(const Key('poc-531-generator')),
      matchesGoldenFile('goldens/poc-531-generator-mobile.png'),
    );
  });
}

Future<void> _pumpGeneratedProgram(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Poc531GeneratorPage(
        core: DomainPoc531GeneratorCore(),
        initialConfiguration: {
          'programId': 'BY-026',
          'generation': 'beyond',
          'unit': 'kg',
          'inputMode': '1RM',
          'trainingMaxRatio': 90.0,
          'days': 4,
          'lifts': {
            'Press': 60.0,
            'Bench Press': 90.0,
            'Squat': 120.0,
            'Deadlift': 150.0,
          },
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  final button = tester.widget<FilledButton>(
    find.byKey(const Key('generate-program')),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await tester.pumpAndSettle();
}

Future<void> _viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
