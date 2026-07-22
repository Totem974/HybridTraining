import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/plating/cycle_plating_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  testWidgets('shows injected equipment and updates plate counts', (
    tester,
  ) async {
    (int, int)? changed;
    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: CyclePlatingBlock(
            denominations: const [
              CyclePlateDenominationView(
                centiUnits: 2500,
                label: '25 kg',
                count: 2,
              ),
              CyclePlateDenominationView(
                centiUnits: 125,
                label: '1.25 kg',
                count: 0,
              ),
            ],
            equipmentProfileLabel: 'Home gym',
            barWeightLabel: '20 kg',
            maximumWeightLabel: '125 kg',
            onCountChanged: (denomination, count) {
              changed = (denomination, count);
            },
          ),
        ),
      ),
    );

    expect(find.text('Home gym'), findsOneWidget);
    expect(find.text('20 kg'), findsOneWidget);
    expect(find.text('125 kg'), findsOneWidget);
    expect(find.text('Rounding increment'), findsNothing);
    expect(find.text('Plates per side'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cycle-plating-add-2500')));
    expect(changed, (2500, 3));
    await tester.tap(find.byKey(const ValueKey('cycle-plating-remove-2500')));
    expect(changed, (2500, 1));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('cycle-plating-remove-125')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('stays overflow-free at 320 pixels', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CyclePlatingBlock(
              denominations: [
                for (final value in [5000, 2500, 2000, 1500, 1000, 500])
                  CyclePlateDenominationView(
                    centiUnits: value,
                    label: '$value',
                    count: 0,
                  ),
              ],
              barWeightLabel: '20 kg',
              maximumWeightLabel: '247.5 kg',
              onCountChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
