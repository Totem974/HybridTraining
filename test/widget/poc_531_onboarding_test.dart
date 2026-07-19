import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/presentation/onboarding/poc_531_onboarding_page.dart';

void main() {
  testWidgets(
    'complete flow recommends and emits the selected CORE configuration',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      core.ProgramConfiguration? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Poc531OnboardingPage(
            onProgramSelected: (value) => selected = value,
          ),
        ),
      );

      for (var step = 0; step < 6; step++) {
        await _continue(tester);
      }
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-lift-overheadPress')),
        '60',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-lift-benchPress')),
        '90',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-lift-squat')),
        '120',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-lift-deadlift')),
        '150',
      );
      await _continue(tester);
      await _continue(tester);

      final legacySwitch = find.text('Autoriser les programmes Legacy');
      final legacyTile = find.ancestor(
        of: legacySwitch,
        matching: find.byType(SwitchListTile),
      );
      tester.widget<SwitchListTile>(legacyTile).onChanged!(true);
      await tester.pump();
      await _continue(tester);

      expect(find.byKey(const Key('recommendation-count')), findsOneWidget);
      expect(find.textContaining('recommandations classées'), findsOneWidget);

      final selectButton = find.text('Choisir et ouvrir le générateur').first;
      await tester.ensureVisible(selectButton);
      await tester.tap(selectButton);
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.lifts.length, core.MainLift.values.length);
      expect(core.validateProgramConfiguration(selected!), isEmpty);
    },
  );

  testWidgets(
    'journey is reversible and powerlifting is only an extension goal',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: Poc531OnboardingPage(onProgramSelected: (_) {})),
      );
      await _continue(tester);
      expect(find.text('Objectif principal'), findsOneWidget);

      tester
          .widget<TextButton>(find.byKey(const Key('onboarding-back')).last)
          .onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('Un programme adapté, sans devinette'), findsOneWidget);
      expect(find.textContaining('powerlifting (extension)'), findsNothing);
    },
  );
}

Future<void> _continue(WidgetTester tester) async {
  final button = find.byKey(const Key('onboarding-continue')).last;
  tester.widget<FilledButton>(button).onPressed!();
  await tester.pumpAndSettle();
}
