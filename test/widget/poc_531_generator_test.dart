import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
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

  testWidgets('warmup offers Original and Beyond with required base weights', (
    tester,
  ) async {
    await openCalculator(tester);
    expect(find.text('None'), findsNothing);
    expect(find.text('Original'), findsWidgets);
    await tester.tap(find.text('Original').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beyond 5/3/1').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('warmup-base-lower')), findsOneWidget);
    expect(find.byKey(const Key('warmup-base-upper')), findsOneWidget);
    expect(find.text('Lower Body'), findsOneWidget);
    expect(find.text('Upper Body'), findsOneWidget);
  });

  testWidgets(
    '1 Rep Max mode displays editable repetitions for all four lifts',
    (tester) async {
      await openCalculator(tester);
      expect(find.byKey(const Key('reps-Press')), findsOneWidget);
      expect(find.byKey(const Key('reps-Bench Press')), findsOneWidget);
      expect(find.byKey(const Key('reps-Squat')), findsOneWidget);
      expect(find.byKey(const Key('reps-Deadlift')), findsOneWidget);
    },
  );

  testWidgets('light input surfaces use dark readable text', (tester) async {
    await openCalculator(tester);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('lift-Press')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.style.color, const Color(0xff181818));
    final fieldContext = tester.element(find.byKey(const Key('lift-Press')));
    final theme = Theme.of(fieldContext);
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
    expect(
      theme.inputDecorationTheme.floatingLabelStyle?.color,
      const Color(0xff9ed4ff),
    );
  });

  testWidgets('Forever switches to the reviewed Leader Anchor calculator', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.text('Forever'));
    await tester.pumpAndSettle();
    expect(find.text('Template Forever exécutable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forever-step-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leader'), findsWidgets);
    expect(find.byKey(const Key('forever-timeline')), findsOneWidget);
    expect(find.text('7th Week Deload'), findsOneWidget);
    expect(find.text('7th Week Training Max Test'), findsOneWidget);
  });

  testWidgets('Forever exposes eight localized composer steps and horizon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('fr'),
        supportedLocales: [Locale('fr'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Poc531GeneratorPage(
          core: DomainPoc531GeneratorCore(),
          initialConfiguration: {'mode': 'forever'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forever-eight-stepper')), findsOneWidget);
    for (var index = 0; index < 8; index++) {
      expect(find.byKey(ValueKey('forever-step-$index')), findsOneWidget);
    }
    expect(find.text('3. Architecture'), findsOneWidget);
    expect(find.text('8. Résumé'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forever-step-1')));
    await tester.pumpAndSettle();
    expect(find.text('M1 · Actif'), findsOneWidget);
    expect(find.text('M2 · Projeté'), findsOneWidget);
    expect(find.text('M3 · Projeté'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forever stepper follows keyboard arrows in English', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('fr'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Poc531GeneratorPage(
          core: DomainPoc531GeneratorCore(),
          initialConfiguration: {'mode': 'forever'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8. Summary'), findsOneWidget);
    expect(find.text('Choose the plan type.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('One macrocycle is generated at a time.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('Choose the plan type.'), findsOneWidget);
  });

  testWidgets(
    'completed M1 enables continuation and appends M2 to v4 payload',
    (tester) async {
      final core = _RecordingGeneratorCore();
      const m1 = {
        'instanceId': 'M1',
        'intent': 'active',
        'status': 'completed',
        'recipeId': 'forever-2l1a-v2',
        'slots': <Object?>[],
        'protocols': <Object?>[],
        'trainingMaxStates': <String, Object?>{},
      };
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Poc531GeneratorPage(
            core: core,
            initialConfiguration: const {
              'schemaVersion': 4,
              'mode': 'forever',
              'common': {'unit': 'kg'},
              'forever': {
                'series': {
                  'id': 'series-test',
                  'terminated': false,
                  'macrocycles': [m1],
                },
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('forever-step-7')));
      await tester.pumpAndSettle();

      final add = find.byKey(const Key('continue-next-macrocycle'));
      expect(tester.widget<OutlinedButton>(add).onPressed, isNotNull);
      final continuationMode = find.byKey(const Key('continuation-mode'));
      await tester.ensureVisible(continuationMode);
      await tester.tap(continuationMode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clone and edit').last);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final forever = core.lastConfiguration!['forever']! as Map;
      final series = forever['series']! as Map;
      final macrocycles = series['macrocycles']! as List;
      expect(macrocycles, hasLength(2));
      expect(macrocycles.first, m1);
      expect((macrocycles.last as Map)['instanceId'], 'M2');
      expect((macrocycles.last as Map)['intent'], 'cloneAndEdit');
      expect((macrocycles.last as Map)['status'], 'active');
    },
  );

  testWidgets('mode selector preserves common inputs and both mode drafts', (
    tester,
  ) async {
    await openCalculator(tester);
    expect(find.text('Cycle 5/3/1'), findsOneWidget);
    expect(find.text('Original, Beyond et extensions'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('lift-Press')), '72');
    await tester.tap(find.byKey(const Key('program')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triumvirate').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forever'));
    await tester.pumpAndSettle();
    expect(find.text('Leaders, Anchors et macrocycles'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forever-step-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forever-timeline')), findsOneWidget);

    await tester.tap(find.text('Cycle 5/3/1'));
    await tester.pumpAndSettle();
    expect(find.text('Triumvirate'), findsWidgets);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('lift-Press')))
          .controller
          ?.text,
      '72',
    );

    await tester.tap(find.text('Forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forever-step-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forever-timeline')), findsOneWidget);
  });

  testWidgets('standalone Forever keeps Beginner Prep School out of 2L/1A', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.text('Forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programme autonome'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Beginner Prep School'), findsWidgets);
    expect(find.text('7th Week Deload'), findsNothing);
    expect(find.text('Utiliser un autre Leader pour C2'), findsNothing);
  });

  testWidgets(
    'Triumvirate is selectable and renders assistance without crash',
    (tester) async {
      await openCalculator(tester);
      await tester.tap(find.byKey(const Key('program')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Triumvirate').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('variant')), findsNothing);
      await tester.tap(find.text('Charger un exemple'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Dips'), findsWidgets);
      expect(find.textContaining('Pull-up'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Bodyweight exposes total reps and set distribution controls', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.byKey(const Key('program')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bodyweight').last);
    await tester.pumpAndSettle();
    expect(find.text('Reps / exercise'), findsOneWidget);
    expect(find.text('Sets'), findsOneWidget);
    expect(find.textContaining('Your sets will be divided'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Forever generation renders prescriptions instead of raw JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Poc531GeneratorPage(
          core: DomainPoc531GeneratorCore(),
          initialConfiguration: {
            'mode': 'forever',
            'foreverTemplateId': 'FV-236',
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
    await tester.tap(find.byKey(const ValueKey('forever-step-7')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('generate-program')))
          .onPressed,
      isNotNull,
      reason: 'The migrated Forever configuration must remain executable.',
    );
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('export-json')),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .join(' | '),
    );
    expect(find.textContaining('"prescriptions"'), findsNothing);
    expect(
      find.text('Prescription disponible dans l’export JSON.'),
      findsNothing,
    );
    expect(find.textContaining('MAIN'), findsWidgets);
  });

  testWidgets('BBB exposes variants and same or per-lift ratios', (
    tester,
  ) async {
    await openCalculator(tester);
    expect(find.byKey(const Key('variant')), findsOneWidget);
    expect(find.text('Use same ratio for all lifts'), findsOneWidget);
    await tester.tap(find.text('Use same ratio for all lifts'));
    await tester.pumpAndSettle();
    expect(find.text('Press ratio'), findsOneWidget);
    expect(find.text('Deadlift ratio'), findsOneWidget);
  });

  testWidgets('Simplest Strength exposes four secondary max inputs', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.byKey(const Key('program')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simplest Strength').last);
    await tester.pumpAndSettle();
    for (final lift in [
      'Close Grip Bench',
      'Incline Press',
      'Front Squat',
      'Straight Leg Deadlift',
    ]) {
      expect(find.text(lift), findsOneWidget);
      expect(
        find.byKey(ValueKey('simplest-strength-weight-$lift')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Scheduling exposes drag handles and Bastard work order', (
    tester,
  ) async {
    await openCalculator(tester);
    expect(find.byType(LongPressDraggable<String>), findsNWidgets(4));
    expect(find.text('Bastard work order'), findsOneWidget);
  });

  testWidgets('GVT is selectable and exposes its sourced ratio options', (
    tester,
  ) async {
    await openCalculator(tester);
    await tester.tap(find.byKey(const Key('program')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('German Volume Training').last);
    await tester.pumpAndSettle();
    expect(find.text('Alternate exercise / Less Boring'), findsOneWidget);
    expect(find.text('10 × 10 ratio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingGeneratorCore implements Poc531GeneratorCore {
  Map<String, Object?>? lastConfiguration;

  @override
  GeneratorOptions get options => const DomainPoc531GeneratorCore().options;

  @override
  Future<GeneratorResult> generate(Map<String, Object?> configuration) async {
    lastConfiguration = configuration;
    return const GeneratorResult(title: 'Recorded', blocks: []);
  }

  @override
  Future<List<GeneratorWarning>> validate(
    Map<String, Object?> configuration,
  ) async {
    lastConfiguration = configuration;
    return const [];
  }

  @override
  Future<String> serializeConfiguration(
    Map<String, Object?> configuration,
  ) async {
    lastConfiguration = configuration;
    return 'recorded';
  }

  @override
  Future<PlateLoadingView> calculatePlateLoading({
    required double weight,
    required double barWeight,
    required List<double> inventory,
    required String unit,
  }) async =>
      const PlateLoadingView(perSide: [], actualWeight: 0, roundingError: 0);
}
