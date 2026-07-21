import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_route.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deep-linked Cycle route generates and saves', (tester) async {
    final application = _IntegrationApplication();
    final route = CycleWebRoute.build(
      settings: const RouteSettings(
        name:
            '/cycle?template=integration_template&variant=integration_variant',
      ),
      application: application,
    );
    await tester.pumpWidget(
      MaterialApp(home: Navigator(onGenerateRoute: (_) => route)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cycle-web-generate')));
    await tester.pumpAndSettle();

    expect(application.requestedSelection, (
      'integration_template',
      'integration_variant',
    ));
    expect(application.saved, isTrue);
    expect(application.generated, isTrue);
  });
}

final class _IntegrationApplication implements CycleWebApplication {
  @override
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  }) async => const [];

  (String, String)? requestedSelection;
  bool saved = false;
  bool generated = false;

  @override
  Future<CycleCatalogIndex> loadIndex() async => const CycleCatalogIndex(
    catalogVersion: 1,
    templates: [
      CycleTemplateSummary(
        id: 'integration_template',
        revision: 1,
        labelEn: 'Integration template',
        labelFr: 'Modèle intégration',
        variantIds: ['integration_variant'],
      ),
    ],
  );

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  }) async {
    requestedSelection = (templateId, variantId);
    return CycleEditorSchema(
      id: 'integration-schema',
      templateId: templateId,
      variantId: variantId,
      options: const <CycleOptionDefinition>[],
    );
  }

  @override
  Future<CycleEditorState?> loadDraft() async => null;

  @override
  Future<void> saveDraft(CycleEditorState state) async => saved = true;

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) async {
    generated = true;
    return GeneratedCycleView(
      GeneratedCycle(
        id: 'integration-cycle',
        catalogVersion: 1,
        templateId: state.templateId,
        variantId: state.variantId,
        effectiveTrainingMaxes: const {},
        weeks: const [],
      ),
    );
  }
}
