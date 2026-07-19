import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in const {
    'Original': 'original-fsl-v1',
    'Beyond': 'beyond-six-week-cycle-v1',
    'Forever': 'forever-original-531-fsl-2l1a-v1',
  }.entries) {
    testWidgets(
      '${scenario.key}: onboarding → recommendation → generator → export',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/poc/531/onboarding',
            onGenerateRoute: buildPoc531Route,
          ),
        );
        await tester.pumpAndSettle();

        for (var step = 0; step < 6; step++) {
          await _advance(tester);
        }
        const lifts = {
          'overheadPress': '60',
          'benchPress': '90',
          'squat': '120',
          'deadlift': '150',
        };
        for (final lift in lifts.entries) {
          await tester.enterText(
            find.byKey(ValueKey('onboarding-lift-${lift.key}')),
            lift.value,
          );
        }
        await _advance(tester);
        await _advance(tester);
        final legacy = find.ancestor(
          of: find.text('Autoriser les programmes Legacy'),
          matching: find.byType(SwitchListTile),
        );
        tester.widget<SwitchListTile>(legacy).onChanged!(true);
        await tester.pump();
        await _advance(tester);

        expect(find.byKey(const Key('recommendation-count')), findsOneWidget);
        final select = find.byKey(ValueKey('select-${scenario.value}'));
        expect(select, findsOneWidget);
        tester.widget<FilledButton>(select).onPressed!();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
        final generate = tester.widget<FilledButton>(
          find.byKey(const Key('generate-program')),
        );
        expect(generate.onPressed, isNotNull);
        generate.onPressed!();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('export-json')), findsOneWidget);
        expect(find.byKey(const Key('plate-panel')), findsOneWidget);
        expect(find.byType(ExpansionTile), findsWidgets);
        tester
            .widget<OutlinedButton>(find.byKey(const Key('export-json')))
            .onPressed!();
        await tester.pump();
      },
    );
  }
}

Future<void> _advance(WidgetTester tester) async {
  final button = find.byKey(const Key('onboarding-continue')).last;
  tester.widget<FilledButton>(button).onPressed!();
  await tester.pumpAndSettle();
}
