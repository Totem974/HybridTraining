import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/scheduling/cycle_scheduling_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  const sessions = [
    CycleSessionTokenView(
      key: 'session-a',
      label: 'OP',
      semanticLabel: 'Overhead Press',
    ),
    CycleSessionTokenView(
      key: 'session-b',
      label: 'SQ+BP',
      semanticLabel: 'Squat and Bench Press',
    ),
    CycleSessionTokenView(
      key: 'session-c',
      label: 'DL',
      semanticLabel: 'Deadlift',
    ),
  ];

  testWidgets('renders visual schedule and only injected capabilities', (
    tester,
  ) async {
    String? moved;
    int? frequency;
    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: CycleSchedulingBlock(
            viewModel: CycleSchedulingViewModel(
              frequency: 3,
              allowedFrequencies: const [
                CycleFrequencyView(value: 3, label: '3'),
                CycleFrequencyView(value: 4, label: '4'),
              ],
              sessions: sessions,
              startDate: DateTime(2026, 7, 22),
              canMoveSessionLeft: const {'session-b'},
              canMoveSessionRight: const {'session-a'},
              bastardWorkOrder: false,
            ),
            onFrequencyChanged: (value) => frequency = value,
            onMoveSessionLeft: (key) => moved = key,
            onMoveSessionRight: (key) => moved = key,
          ),
        ),
      ),
    );

    expect(find.text('OP'), findsOneWidget);
    expect(find.text('SQ+BP'), findsOneWidget);
    expect(find.text('DL'), findsOneWidget);
    expect(find.textContaining('session-a'), findsNothing);
    expect(find.text('3/5/1 week order'), findsNothing);
    expect(
      find.byKey(const Key('cycle-scheduling-bastard-order')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('cycle-scheduling-left-session-b')),
    );
    expect(moved, 'session-b');
    expect(
      find.byKey(const ValueKey('cycle-scheduling-left-session-a')),
      findsNothing,
    );
    await tester.tap(find.text('4'));
    expect(frequency, 4);
  });

  testWidgets('locks a single frequency and fits narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CycleSchedulingBlock(
              viewModel: CycleSchedulingViewModel(
                frequency: 3,
                allowedFrequencies: const [
                  CycleFrequencyView(value: 3, label: '3'),
                ],
                sessions: sessions,
                startDate: DateTime(2026, 7, 22),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('cycle-scheduling-frequency-locked')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('cycle-scheduling-frequency')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
