import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/blocks/template/cycle_template_block.dart';
import 'package:hybrid_training/features/generator_web/design/hybrid_generator_design.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';

void main() {
  const index = CycleCatalogIndex(
    catalogVersion: 1,
    templates: [
      CycleTemplateSummary(
        id: 'bbb',
        revision: 1,
        labelEn: 'Boring But Big',
        labelFr: 'Boring But Big',
        variantIds: ['standard', 'challenge'],
      ),
      CycleTemplateSummary(
        id: 'fsl',
        revision: 1,
        labelEn: 'First Set Last',
        labelFr: 'Première série finale',
        variantIds: ['five-by-five'],
      ),
    ],
  );

  testWidgets('renders source-style rows and injected dynamic options', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const CycleTemplateBlock(
          index: index,
          state: CycleEditorState(templateId: 'bbb', variantId: 'challenge'),
          templateLabelBuilder: _templateLabel,
          variantLabelBuilder: _variantLabel,
          onTemplateSelected: _ignore,
          onVariantSelected: _ignore,
          options: Text('Catalogue option'),
        ),
      ),
    );

    expect(find.text('TEMPLATE'), findsOneWidget);
    expect(find.text('Boring But Big'), findsOneWidget);
    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('Catalogue option'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('selects catalogue templates from a contained popup', (
    tester,
  ) async {
    String? selection;
    await tester.pumpWidget(
      _harness(
        CycleTemplateBlock(
          index: index,
          state: const CycleEditorState(
            templateId: 'bbb',
            variantId: 'standard',
          ),
          templateLabelBuilder: _templateLabel,
          variantLabelBuilder: _variantLabel,
          onTemplateSelected: (value) => selection = value,
          onVariantSelected: _ignore,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('cycle-web-template')));
    await tester.pumpAndSettle();

    expect(find.text('First Set Last'), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));

    await tester.tap(find.text('First Set Last'));
    await tester.pumpAndSettle();
    expect(selection, 'fsl');
  });
}

Widget _harness(Widget child) => MaterialApp(
  theme: HybridGeneratorTokens.theme(),
  home: Scaffold(body: SizedBox(width: 440, child: child)),
);

String _templateLabel(CycleTemplateSummary value) => value.labelEn;

String _variantLabel(String value) => switch (value) {
  'standard' => 'Standard',
  'challenge' => 'Challenge',
  'five-by-five' => 'Five by five',
  _ => value,
};

void _ignore(String _) {}
