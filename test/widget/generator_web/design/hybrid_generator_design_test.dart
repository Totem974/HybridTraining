import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  testWidgets('desktop shell centers a two-column card grid', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());

    final shell = tester.widget<Scaffold>(
      find.byKey(const Key('hybrid-generator-shell')),
    );
    expect(shell.backgroundColor, isNull);
    expect(find.text('HYBRID 5/3/1'), findsOneWidget);
    expect(find.text('CALCULATOR'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.text('TEMPLATE'), findsOneWidget);
    final first = tester.getRect(find.byKey(const Key('card-one')));
    final second = tester.getRect(find.byKey(const Key('card-two')));
    expect(first.top, second.top);
    expect(first.right, lessThan(second.left));
    expect(first.left, greaterThanOrEqualTo(150));
  });

  testWidgets('mobile shell stacks header and cards without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());

    final first = tester.getRect(find.byKey(const Key('card-one')));
    final second = tester.getRect(find.byKey(const Key('card-two')));
    expect(second.top, greaterThan(first.bottom));
    expect(find.text('HYBRID 5/3/1'), findsOneWidget);
    expect(find.text('CALCULATOR'), findsOneWidget);
    expect(
      find.byKey(const Key('hybrid-generator-page-toggle')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page toggle announces and requests the other page', (
    tester,
  ) async {
    HybridGeneratorPage? destination;
    await tester.pumpWidget(_app(onNavigate: (value) => destination = value));

    await tester.tap(find.text('Macrocycle'));
    await tester.pump();

    expect(destination, HybridGeneratorPage.forever);
    expect(
      find.byKey(const Key('hybrid-generator-page-toggle')),
      findsOneWidget,
    );
    final toggle = tester.widget<SegmentedButton<HybridGeneratorPage>>(
      find.byKey(const Key('hybrid-generator-page-toggle')),
    );
    expect(toggle.selected, {HybridGeneratorPage.cycle});
  });

  testWidgets('cards retain the validated dark rounded visual language', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    final theme = Theme.of(
      tester.element(find.byKey(const Key('hybrid-generator-shell'))),
    );
    expect(theme.scaffoldBackgroundColor, HybridGeneratorTokens.background);
    expect(theme.colorScheme.primary, HybridGeneratorTokens.accent);
    expect(theme.cardTheme.color, HybridGeneratorTokens.surface);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      BorderRadius.circular(HybridGeneratorTokens.radius),
    );
  });
}

Widget _app({ValueChanged<HybridGeneratorPage>? onNavigate}) => MaterialApp(
  theme: HybridGeneratorTokens.theme(),
  home: HybridGeneratorShell(
    page: HybridGeneratorPage.cycle,
    title: 'Cycle generator',
    onNavigate: onNavigate,
    child: HybridGeneratorGrid(
      children: const [
        HybridGeneratorCard(
          key: Key('card-one'),
          title: 'Weight',
          child: Text('Maxes'),
        ),
        HybridGeneratorCard(
          key: Key('card-two'),
          title: 'Template',
          child: Text('Variants'),
        ),
      ],
    ),
  ),
);
