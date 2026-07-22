import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/weight/cycle_weight_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  const movements = ['overhead_press', 'bench_press', 'squat', 'deadlift'];

  testWidgets('presents one global max mode and one global TM ratio', (
    tester,
  ) async {
    CycleMaxInputKind? selectedKind;
    await tester.pumpWidget(
      _Harness(
        child: CycleWeightBlock(
          state: _state(),
          movementIds: movements,
          onMaxInputKindChanged: (kind) => selectedKind = kind,
          onMovementInputChanged: (_, _) {},
          onGlobalTrainingMaxRatioChanged: (_) {},
          onUnitChanged: (_) {},
        ),
      ),
    );

    expect(find.byKey(const Key('cycle-web-max-mode')), findsOneWidget);
    expect(find.text('Training Max Ratio'), findsOneWidget);
    expect(find.text('Global TM ratio (%)'), findsNothing);
    expect(
      find.byKey(const ValueKey('cycle-web-global-ratio')),
      findsOneWidget,
    );
    expect(find.text('1'), findsNWidgets(4));

    await tester.tap(find.text('Training Max'));
    await tester.pump();
    expect(selectedKind, CycleMaxInputKind.directTrainingMax);
  });

  testWidgets('rep max exposes repetitions and forwards values without maths', (
    tester,
  ) async {
    CycleMovementMaxInput? changed;
    await tester.pumpWidget(
      _Harness(
        child: CycleWeightBlock(
          state: _state(kind: CycleMaxInputKind.repMax),
          movementIds: movements,
          onMaxInputKindChanged: (_) {},
          onMovementInputChanged: (id, input) {
            if (id == 'squat') changed = input;
          },
          onGlobalTrainingMaxRatioChanged: (_) {},
          onUnitChanged: (_) {},
        ),
      ),
    );

    final repetitions = find.byKey(const Key('cycle-web-max-reps-squat'));
    expect(repetitions, findsOneWidget);
    await tester.enterText(repetitions, '7');
    expect(changed?.kind, CycleMaxInputKind.repMax);
    expect(changed?.repetitions, 7);
    expect(changed?.weightCentiUnits, 12500);
  });

  testWidgets('unit selector is segmented and forwards the selected unit', (
    tester,
  ) async {
    WeightUnit? changed;
    await tester.pumpWidget(
      _Harness(
        child: CycleWeightBlock(
          state: _state(),
          movementIds: movements,
          onMaxInputKindChanged: (_) {},
          onMovementInputChanged: (_, _) {},
          onGlobalTrainingMaxRatioChanged: (_) {},
          onUnitChanged: (unit) => changed = unit,
        ),
      ),
    );

    expect(find.byKey(const Key('cycle-web-unit')), findsOneWidget);
    await tester.tap(find.text('lb').last);
    await tester.pump();
    expect(changed, WeightUnit.lb);
  });
}

CycleEditorState _state({
  CycleMaxInputKind kind = CycleMaxInputKind.oneRepMax,
}) => CycleEditorState(
  templateId: 'catalogue-template',
  variantId: 'catalogue-variant',
  maxInputs: {
    'overhead_press': CycleMovementMaxInput(
      kind: kind,
      weightCentiUnits: 6500,
      repetitions: kind == CycleMaxInputKind.repMax ? 3 : null,
    ),
    'bench_press': CycleMovementMaxInput(
      kind: kind,
      weightCentiUnits: 9000,
      repetitions: kind == CycleMaxInputKind.repMax ? 3 : null,
    ),
    'squat': CycleMovementMaxInput(
      kind: kind,
      weightCentiUnits: 12500,
      repetitions: kind == CycleMaxInputKind.repMax ? 3 : null,
    ),
    'deadlift': CycleMovementMaxInput(
      kind: kind,
      weightCentiUnits: 16500,
      repetitions: kind == CycleMaxInputKind.repMax ? 3 : null,
    ),
  },
);

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: HybridGeneratorTokens.theme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 440,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}
