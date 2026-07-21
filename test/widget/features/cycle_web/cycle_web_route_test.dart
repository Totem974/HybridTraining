import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_route.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';

void main() {
  testWidgets('deep link selects catalogue-provided template and variant', (
    tester,
  ) async {
    final application = _RouteApplication();
    final route = CycleWebRoute.build(
      settings: const RouteSettings(
        name: '/cycle?template=dynamic_template&variant=dynamic_variant_b',
      ),
      application: application,
    );
    expect(route, isNotNull);
    await tester.pumpWidget(
      MaterialApp(home: Navigator(onGenerateRoute: (_) => route)),
    );
    await tester.pumpAndSettle();

    expect(application.schemaRequests.single, (
      'dynamic_template',
      'dynamic_variant_b',
    ));
    expect(find.text('Dynamic template'), findsOneWidget);
    expect(find.text('Dynamic variant b'), findsOneWidget);
  });

  testWidgets('route generation saves through the injected application', (
    tester,
  ) async {
    final application = _RouteApplication();
    final route = CycleWebRoute.build(
      settings: const RouteSettings(name: '/cycle'),
      application: application,
    );
    await tester.pumpWidget(
      MaterialApp(home: Navigator(onGenerateRoute: (_) => route)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cycle-web-generate')));
    await tester.pumpAndSettle();

    expect(application.savedStates, hasLength(1));
    expect(application.generatedStates, hasLength(1));
    expect(find.text('Saved preview'), findsOneWidget);
  });

  test('route delegates Forever and contains no programme IDs or lists', () {
    expect(
      CycleWebRoute.build(
        settings: const RouteSettings(name: '/poc/531/generator?mode=forever'),
        application: _RouteApplication(),
      ),
      isNull,
    );
    final source = File(
      'lib/features/cycle_web/presentation/cycle_web_route.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('standard_531')));
    expect(source, isNot(contains('boring_but_big')));
    expect(source, isNot(contains('variantIds =')));
    expect(source, isNot(contains('switch (templateId)')));
  });
}

final class _RouteApplication implements CycleWebApplication {
  final schemaRequests = <(String, String)>[];
  final savedStates = <CycleEditorState>[];
  final generatedStates = <CycleEditorState>[];

  @override
  Future<CycleCatalogIndex> loadIndex() async => const CycleCatalogIndex(
    catalogVersion: 1,
    templates: [
      CycleTemplateSummary(
        id: 'dynamic_template',
        revision: 1,
        labelEn: 'Dynamic template',
        labelFr: 'Modèle dynamique',
        variantIds: ['dynamic_variant_a', 'dynamic_variant_b'],
      ),
    ],
  );

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  }) async {
    schemaRequests.add((templateId, variantId));
    return CycleEditorSchema(
      id: '$templateId-$variantId',
      templateId: templateId,
      variantId: variantId,
      options: const <CycleOptionDefinition>[],
    );
  }

  @override
  Future<CycleEditorState?> loadDraft() async => null;

  @override
  Future<void> saveDraft(CycleEditorState state) async {
    savedStates.add(state);
  }

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) async {
    generatedStates.add(state);
    return GeneratedCycleView(
      GeneratedCycle(
        id: 'route-cycle',
        catalogVersion: 1,
        templateId: state.templateId,
        variantId: state.variantId,
        effectiveTrainingMaxes: const {},
        weeks: const [],
      ),
    );
  }
}
