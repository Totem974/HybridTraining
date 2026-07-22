import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/additional_options/additional_options_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  AdditionalOptionGroup group(String id, String label) => AdditionalOptionGroup(
    id: id,
    label: label,
    children: [Text('$label control', key: ValueKey('$id-control'))],
  );

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    List<AdditionalOptionGroup>? secondary,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: AdditionalOptionsBlock(
            title: 'Additional options',
            primaryGroups: [
              group('warmup', 'Warm-up'),
              group('joker', 'Joker sets'),
              group('deload', 'Deload'),
            ],
            secondaryGroups: secondary ?? const [],
          ),
        ),
      ),
    );
  }

  testWidgets('lays the three injected primary groups out in desktop columns', (
    tester,
  ) async {
    await pump(tester, width: 900);

    final warmup = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-warmup')),
    );
    final joker = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-joker')),
    );
    final deload = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-deload')),
    );

    expect(joker.dy, warmup.dy);
    expect(deload.dy, warmup.dy);
    expect(warmup.dx, lessThan(joker.dx));
    expect(joker.dx, lessThan(deload.dx));
  });

  testWidgets('stacks primary groups on narrow layouts', (tester) async {
    await pump(tester, width: 390);

    final warmup = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-warmup')),
    );
    final joker = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-joker')),
    );
    final deload = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-deload')),
    );

    expect(warmup.dy, lessThan(joker.dy));
    expect(joker.dy, lessThan(deload.dy));
  });

  testWidgets('places remaining catalogue groups in a second row', (
    tester,
  ) async {
    await pump(
      tester,
      width: 900,
      secondary: [group('assistance', 'Assistance')],
    );

    final primaryBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('additional-options-group-warmup')),
    );
    final secondaryTop = tester.getTopLeft(
      find.byKey(const ValueKey('additional-options-group-assistance')),
    );
    expect(secondaryTop.dy, greaterThan(primaryBottom.dy));
    expect(find.byKey(const Key('additional-options-secondary-row')), findsOne);
  });

  testWidgets('uses only caller-supplied labels and controls', (tester) async {
    await pump(tester, width: 900);

    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.text('JOKER SETS'), findsOneWidget);
    expect(find.text('DELOAD'), findsOneWidget);
    expect(find.byKey(const ValueKey('warmup-control')), findsOneWidget);
  });
}
