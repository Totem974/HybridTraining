import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hybrid_training/features/poc_531/data/forever_series_configuration_repository.dart';
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
    if (configuration['mode'] == 'forever') {
      await tester.tap(find.byKey(const ValueKey('forever-step-7')));
      await tester.pumpAndSettle();
    }
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

  testWidgets('Forever series completes M2 and exports final v4 JSON', (
    tester,
  ) async {
    final seriesId =
        'browser-e2e-${DateTime.now().microsecondsSinceEpoch.toString()}';
    final repository = createLocalForeverSeriesConfigurationRepository();
    String? copiedJson;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedJson = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Poc531GeneratorPage(
          core: const DomainPoc531GeneratorCore(),
          foreverSeriesRepository: repository,
          initialSeriesId: seriesId,
          initialConfiguration: const {
            'mode': 'forever',
            'foreverTemplateId': 'FV-236',
            'lifts': lifts,
            'inputMode': 'tm',
            'days': 4,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forever-step-7')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-json')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('complete-active-macrocycle')),
    );
    await tester.tap(find.byKey(const Key('complete-active-macrocycle')));
    await tester.pumpAndSettle();

    final addNext = find.byKey(const Key('continue-next-macrocycle'));
    expect(tester.widget<OutlinedButton>(addNext).onPressed, isNotNull);
    await tester.ensureVisible(addNext);
    await tester.tap(addNext);
    await tester.pumpAndSettle();

    expect(find.text('M1 · Completed'), findsOneWidget);
    expect(find.text('M2 · Projected'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('export-json')), findsOneWidget);

    Future<void> tapVisible(Key key) async {
      final finder = find.byKey(key);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapVisible(const Key('activate-next-macrocycle'));
    final pressDecision = find.byKey(const Key('tm-decision-press'));
    await tester.ensureVisible(pressDecision);
    await tester.tap(pressDecision);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a value').last);
    await tester.pumpAndSettle();
    expect(find.text('Between 62.5 and 65'), findsOneWidget);
    await tester.tap(pressDecision);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply proposal').last);
    await tester.pumpAndSettle();

    await tapVisible(const Key('complete-active-macrocycle'));
    await tapVisible(const Key('terminate-forever-series'));
    final generateProgram = find.byKey(const Key('generate-program'));
    expect(tester.widget<FilledButton>(generateProgram).onPressed, isNotNull);
    await tapVisible(const Key('generate-program'));

    final export = find.byKey(const Key('export-json'));
    expect(export, findsOneWidget);
    await tester.tap(export);
    await tester.pump();

    final payload = jsonDecode(copiedJson!) as Map<String, dynamic>;
    expect(payload['schemaVersion'], 4);
    expect(payload['terminated'], isTrue);
    final macrocycles = payload['macrocycles'] as List<dynamic>;
    expect(macrocycles, hasLength(2));
    expect(macrocycles.map((value) => value['status']), [
      'completed',
      'completed',
    ]);
    expect(
      macrocycles.map(
        (value) => value['trainingMaxStates']['press']['trainingMax'],
      ),
      [62.5, 65],
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Poc531GeneratorPage(
          core: const DomainPoc531GeneratorCore(),
          foreverSeriesRepository: repository,
          initialSeriesId: seriesId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forever-step-1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('M1'), findsOneWidget);
    expect(find.textContaining('M2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forever-step-7')));
    await tester.pumpAndSettle();
    final restoredContinuation = find.byKey(
      const Key('continue-next-macrocycle'),
    );
    final restoredTermination = find.byKey(
      const Key('terminate-forever-series'),
    );
    expect(
      tester.widget<OutlinedButton>(restoredContinuation).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(restoredTermination).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
