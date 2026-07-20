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

  testWidgets('captures Forever timeline on desktop', (tester) async {
    await _viewport(tester, const Size(1200, 900));
    await _pumpGeneratedProgram(tester, forever: true);
    await expectLater(
      find.byKey(const Key('poc-531-generator')),
      matchesGoldenFile('goldens/poc-531-forever-desktop.png'),
    );
  });

  testWidgets('captures Forever timeline on mobile without overflow', (
    tester,
  ) async {
    await _viewport(tester, const Size(390, 844));
    await _pumpGeneratedProgram(tester, forever: true);
    await expectLater(
      find.byKey(const Key('poc-531-generator')),
      matchesGoldenFile('goldens/poc-531-forever-mobile.png'),
    );
  });
}

Future<void> _pumpGeneratedProgram(
  WidgetTester tester, {
  bool forever = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Poc531GeneratorPage(
        core: const DomainPoc531GeneratorCore(),
        initialConfiguration: {
          'programId': forever ? 'FV-236' : 'BY-026',
          'generation': forever ? 'forever' : 'beyond',
          if (forever) 'mode': 'forever',
          if (forever) 'foreverTemplateId': 'FV-236',
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
  if (forever) {
    await tester.tap(find.byKey(const ValueKey('forever-step-7')));
    await tester.pumpAndSettle();
  }
  final button = tester.widget<FilledButton>(
    find.byKey(const Key('generate-program')),
  );
  expect(button.onPressed, isNotNull);
  button.onPressed!();
  await tester.pumpAndSettle();
  if (forever) {
    await tester.tap(find.byKey(const ValueKey('forever-step-2')));
    await tester.pumpAndSettle();
  }
}

Future<void> _viewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
