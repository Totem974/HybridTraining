import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

void main() {
  testWidgets('example generates a visible week and exports JSON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final core = _FakeCore();
    await tester.pumpWidget(MaterialApp(home: Poc531GeneratorPage(core: core)));

    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
    await tester.ensureVisible(find.text('Charger un exemple'));
    await tester.tap(find.text('Charger un exemple'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('generate-program')));
    await tester.tap(find.byKey(const Key('generate-program')));
    await tester.pumpAndSettle();

    expect(find.text('Cycle test'), findsOneWidget);
    expect(find.text('Semaine 1'), findsOneWidget);
    expect(find.text('Press — séance 1'), findsOneWidget);
    expect(find.byKey(const Key('export-json')), findsOneWidget);
    expect(core.generated, isTrue);
  });

  testWidgets('generation change refreshes compatible programs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: Poc531GeneratorPage(core: _FakeCore())),
    );
    await tester.ensureVisible(find.byKey(const Key('generation')));
    await tester.tap(find.byKey(const Key('generation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5/3/1 Forever').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Leader / Anchor'), findsOneWidget);
  });

  testWidgets('core validation error disables generation', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: Poc531GeneratorPage(core: _FakeCore(invalid: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Combinaison non exécutable'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('generate-program')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('restores ratio, rep mode, repetitions and lifts faithfully', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Poc531GeneratorPage(
          core: _FakeCore(),
          initialConfiguration: const {
            'programId': 'original-test',
            'generation': 'original',
            'status': 'all',
            'unit': 'lb',
            'inputMode': 'Rep max',
            'trainingMaxRatio': 85.0,
            'days': 4,
            'lifts': {
              'Press': 100.0,
              'Bench Press': 200.0,
              'Squat': 300.0,
              'Deadlift': 400.0,
            },
            'repetitions': {
              'Press': 5,
              'Bench Press': 4,
              'Squat': 3,
              'Deadlift': 2,
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('tm-ratio')))
          .controller!
          .text,
      '85.0',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('lift-Squat')))
          .controller!
          .text,
      '300.0',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('reps-Deadlift')))
          .controller!
          .text,
      '2',
    );
  });
}

class _FakeCore implements Poc531GeneratorCore {
  _FakeCore({this.invalid = false});
  final bool invalid;
  bool generated = false;

  @override
  GeneratorOptions get options => const GeneratorOptions(
    programs: [
      ProgramChoice(
        id: 'original-test',
        name: 'Original test',
        generation: 'original',
        family: 'Original',
        variant: 'Standard',
        status: 'current',
      ),
      ProgramChoice(
        id: 'forever-test',
        name: 'Forever test',
        generation: 'forever',
        family: 'Forever',
        variant: 'Leader',
        status: 'current',
      ),
    ],
    supplemental: ['Aucun', 'FSL'],
    assistance: ['Minimal', 'Complet'],
    conditioning: ['Optionnel', 'Modéré'],
    transitions: ['Selon le programme', '7th Week'],
  );

  @override
  Future<GeneratorResult> generate(Map<String, Object?> configuration) async {
    generated = true;
    return const GeneratorResult(
      title: 'Programme de test',
      explanation: 'Décisions fournies par le CORE.',
      exportJson: '{"schemaVersion":1}',
      sources: ['Source structurée, p. 1'],
      blocks: [
        PlanBlockView('Cycle test', [
          PlanWeekView('Semaine 1', [
            PlanSessionView('Press — séance 1', [
              '3 × 5 · 40 kg · 65 %',
              'Assistance : fournie par le CORE',
            ]),
          ]),
        ]),
      ],
    );
  }

  @override
  Future<List<GeneratorWarning>> validate(
    Map<String, Object?> configuration,
  ) async => invalid
      ? const [GeneratorWarning('Combinaison non exécutable', isError: true)]
      : const [];

  @override
  Future<String> serializeConfiguration(
    Map<String, Object?> configuration,
  ) async => 'poc531:test';

  @override
  Future<PlateLoadingView> calculatePlateLoading({
    required double weight,
    required double barWeight,
    required List<double> inventory,
    required String unit,
  }) async => PlateLoadingView(
    perSide: const [20, 10],
    actualWeight: weight,
    roundingError: 0,
  );
}
