import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/output/cycle_output_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';

void main() {
  testWidgets('edits output options and exposes generation actions', (
    tester,
  ) async {
    String? title;
    bool? plating;
    var generated = false;
    var exported = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: HybridGeneratorTokens.theme(),
        home: Scaffold(
          body: CycleOutputBlock(
            programTitle: '',
            showPlating: true,
            onProgramTitleChanged: (value) => title = value,
            onShowPlatingChanged: (value) => plating = value,
            onGenerate: () => generated = true,
            onExport: () => exported = true,
            isFrench: true,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('cycle-output-title')),
      'Force',
    );
    await tester.tap(find.byKey(const Key('cycle-output-show-plating')));
    await tester.tap(find.byKey(const Key('cycle-web-generate')));
    await tester.tap(find.byKey(const Key('cycle-web-export')));

    expect(title, 'Force');
    expect(plating, isFalse);
    expect(generated, isTrue);
    expect(exported, isTrue);
    expect(find.text('Générer'), findsOneWidget);
    expect(find.text('Générer et sauvegarder'), findsNothing);
  });
}
