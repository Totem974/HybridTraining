import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/program/cycle_program.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  final view = GeneratedCycleView(
    GeneratedCycle(
      id: 'cycle',
      catalogVersion: 1,
      templateId: 'template_internal',
      variantId: 'variant_internal',
      effectiveTrainingMaxes: const {},
      weeks: [
        GeneratedWeek(
          number: 1,
          sessions: [
            GeneratedSession(
              id: 'session_internal',
              date: DateTime(2026, 7, 22),
              movementId: const MovementId('overhead_press'),
              blocks: [
                GeneratedBlock(
                  id: 'block_internal',
                  role: 'main_work',
                  movementId: const MovementId('overhead_press'),
                  sets: const [
                    GeneratedSet(
                      index: 1,
                      repetitions: {'type': 'fixed', 'count': 5},
                      percentageBasisPoints: 6500,
                      plannedLoad: Weight(4250, WeightUnit.kg),
                      platesPerSide: [Weight(1000, WeightUnit.kg)],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  testWidgets('shows readable sets without technical identifiers', (
    tester,
  ) async {
    await _pump(tester, view: view, showPlating: true);

    expect(find.text('WEEK 1'), findsOneWidget);
    expect(find.text('OVERHEAD PRESS'), findsOneWidget);
    expect(find.text('MAIN WORK · Overhead Press'), findsOneWidget);
    expect(find.text('5 × 42.5 kg'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.textContaining('internal'), findsNothing);
    expect(find.textContaining('{type:'), findsNothing);
  });

  testWidgets('does not build plate pills when plating is hidden', (
    tester,
  ) async {
    await _pump(tester, view: view, showPlating: false);
    expect(find.byKey(const Key('cycle-program-plate')), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required GeneratedCycleView view,
  required bool showPlating,
}) => tester.pumpWidget(
  MaterialApp(
    theme: HybridGeneratorTokens.theme(),
    home: Scaffold(
      body: SizedBox(
        width: 900,
        child: CycleProgram(
          view: view,
          showPlating: showPlating,
          labelFor: (value) => switch (value) {
            'overhead_press' => 'Overhead Press',
            'main_work' => 'Main Work',
            _ => value,
          },
        ),
      ),
    ),
  ),
);
