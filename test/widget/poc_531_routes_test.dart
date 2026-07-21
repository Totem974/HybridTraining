import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';

void main() {
  testWidgets('web POC mode starts on the injected Cycle catalogue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HybridTrainingApp(
        environment: AppEnvironment.dev,
        pocOnlyMode: true,
        cycleApplication: _CycleApplication(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cycle-web-page')), findsOneWidget);
  });

  testWidgets('root POC route opens the single calculator page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(initialRoute: '/poc/531', onGenerateRoute: buildPoc531Route),
    );
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
    expect(find.byKey(const Key('program')), findsOneWidget);
    expect(find.byKey(const Key('poc-531-onboarding')), findsNothing);
  });

  testWidgets('direct Forever program route opens calculator in Forever mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/poc/531/program/FV-236',
        onGenerateRoute: buildPoc531Route,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poc-531-generator')), findsOneWidget);
    expect(find.text('Template Forever exécutable'), findsOneWidget);
    expect(find.textContaining('Leader'), findsWidgets);
  });

  testWidgets('generator restores Forever mode from the query string', (
    tester,
  ) async {
    final route = buildPoc531Route(
      const RouteSettings(name: '/poc/531/generator?mode=forever'),
    );
    expect(route, isNotNull);
    await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forever-timeline')), findsOneWidget);
    expect(find.text('Leaders, Anchors et macrocycles'), findsOneWidget);
  });
}

final class _CycleApplication implements CycleWebApplication {
  const _CycleApplication();

  @override
  Future<CycleCatalogIndex> loadIndex() async => const CycleCatalogIndex(
    catalogVersion: 1,
    templates: [
      CycleTemplateSummary(
        id: 'cycle',
        revision: 1,
        labelEn: 'Cycle',
        labelFr: 'Cycle',
        variantIds: ['variant'],
      ),
    ],
  );

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  }) async => CycleEditorSchema(
    id: 'schema',
    templateId: templateId,
    variantId: variantId,
    options: const <CycleOptionDefinition>[],
  );

  @override
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  }) async => const [];

  @override
  Future<List<String>> loadSessionIds({
    required String templateId,
    required String variantId,
  }) async => const ['squat'];

  @override
  Future<CycleEditorState?> loadDraft() async => null;

  @override
  Future<void> saveDraft(CycleEditorState state) async {}

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) async =>
      GeneratedCycleView(
        GeneratedCycle(
          id: 'cycle',
          catalogVersion: 1,
          templateId: state.templateId,
          variantId: state.variantId,
          effectiveTrainingMaxes: const {},
          weeks: const [],
        ),
      );
}
