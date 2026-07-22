import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_page.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';

void main() {
  testWidgets('shows the Cycle Macrocycle switch and every generator block', (
    tester,
  ) async {
    final application = _FakeCycleWebApplication();
    await tester.pumpWidget(
      MaterialApp(home: CycleWebPage(application: application)),
    );
    await tester.pumpAndSettle();

    expect(find.text('HYBRID 5/3/1'), findsOneWidget);
    expect(find.text('CALCULATOR'), findsOneWidget);
    expect(
      find.byKey(const Key('hybrid-generator-page-toggle')),
      findsOneWidget,
    );
    expect(find.text('Cycle'), findsOneWidget);
    expect(find.text('Macrocycle'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.text('TEMPLATE'), findsOneWidget);
    expect(find.text('ADDITIONAL OPTIONS'), findsOneWidget);
    expect(find.text('PLATING & BARBELL'), findsOneWidget);
    expect(find.text('SCHEDULING'), findsOneWidget);

    expect(find.byKey(const Key('cycle-web-plates')), findsNothing);
    expect(find.byKey(const Key('cycle-web-rounding')), findsNothing);
    expect(find.byKey(const Key('cycle-plating-bar-weight')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cycle-web-max-weight-squat')),
      '100',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cycle-web-generate')));
    await tester.tap(find.byKey(const Key('cycle-web-generate')));
    await tester.pumpAndSettle();

    expect(find.text('PROGRAM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps the complete generator layout overflow-free responsively',
    (tester) async {
      final application = _FakeCycleWebApplication();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in const [
        Size(1440, 1000),
        Size(390, 844),
        Size(320, 568),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(home: CycleWebPage(application: application)),
        );
        await tester.pumpAndSettle();

        expect(find.text('WEIGHT'), findsOneWidget);
        expect(find.text('TEMPLATE'), findsOneWidget);
        expect(find.text('ADDITIONAL OPTIONS'), findsOneWidget);
        expect(find.text('PLATING & BARBELL'), findsOneWidget);
        expect(find.text('SCHEDULING'), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        await tester.ensureVisible(find.text('SCHEDULING'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cycle-web-generate')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    },
  );

  testWidgets('renders catalogue templates and generic conditional options', (
    tester,
  ) async {
    final application = _FakeCycleWebApplication();
    await tester.pumpWidget(
      MaterialApp(home: CycleWebPage(application: application)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalogue Program'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    expect(find.text('TEMPLATE'), findsOneWidget);
    expect(find.text('ADDITIONAL OPTIONS'), findsOneWidget);
    expect(find.text('PLATING & BARBELL'), findsOneWidget);
    expect(find.text('SCHEDULING'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
    expect(find.text('Advanced load'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('cycle-option-advanced')),
    );
    await tester.tap(find.byKey(const ValueKey('cycle-option-advanced')));
    await tester.pumpAndSettle();
    expect(find.text('Advanced load'), findsOneWidget);
    expect(application.savedDrafts, isNotEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('cycle-web-max-weight-squat')),
      '100',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('cycle-web-generate')));
    await tester.tap(find.byKey(const Key('cycle-web-generate')));
    await tester.pumpAndSettle();
    expect(application.generatedStates, hasLength(1));
    expect(find.byKey(const ValueKey('cycle-program-week-1')), findsOneWidget);
  });

  testWidgets('switches variants through index data and stays responsive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final application = _FakeCycleWebApplication();
    await tester.pumpWidget(
      MaterialApp(home: CycleWebPage(application: application)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cycle-web-variant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second variant').last);
    await tester.pumpAndSettle();
    expect(application.schemaRequests.last, (
      'catalogue_program',
      'second_variant',
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded editor reuses fields without page generation actions', (
    tester,
  ) async {
    final application = _FakeCycleWebApplication();
    CycleEditorState? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CycleEditorPanel(
            application: application,
            initialState: const CycleEditorState(
              templateId: 'catalogue_program',
              variantId: 'first_variant',
            ),
            onChanged: (state) => changed = state,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cycle-editor-panel')), findsOneWidget);
    expect(find.byKey(const Key('cycle-web-generate')), findsNothing);
    expect(find.byKey(const Key('cycle-web-template')), findsOneWidget);
    expect(changed?.templateId, 'catalogue_program');
  });
}

final class _FakeCycleWebApplication implements CycleWebApplication {
  final savedDrafts = <CycleEditorState>[];
  final generatedStates = <CycleEditorState>[];
  final schemaRequests = <(String, String)>[];

  @override
  Future<CycleCatalogIndex> loadIndex() async => const CycleCatalogIndex(
    catalogVersion: 3,
    templates: [
      CycleTemplateSummary(
        id: 'catalogue_program',
        revision: 1,
        labelEn: 'Catalogue Program',
        labelFr: 'Programme catalogue',
        variantIds: ['first_variant', 'second_variant'],
      ),
    ],
  );

  @override
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  }) async => const ['squat'];

  @override
  Future<List<String>> loadSessionIds({
    required String templateId,
    required String variantId,
  }) async => const ['squat'];

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
      options: const [
        CycleOptionDefinition(
          id: 'advanced',
          type: CycleOptionType.boolean,
          scope: CycleOptionScope.global,
          defaultValue: false,
        ),
        CycleOptionDefinition(
          id: 'advanced_load',
          type: CycleOptionType.weight,
          scope: CycleOptionScope.global,
          defaultValue: 50.0,
          minimum: 1,
          maximum: 100,
          visibleWhen: EqualsCondition('advanced', true),
          requiredWhen: EqualsCondition('advanced', true),
        ),
      ],
    );
  }

  @override
  Future<CycleEditorState?> loadDraft() async => null;

  @override
  Future<void> saveDraft(CycleEditorState state) async {
    savedDrafts.add(state);
  }

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) async {
    generatedStates.add(state);
    return GeneratedCycleView(
      GeneratedCycle(
        id: 'generated',
        catalogVersion: 3,
        templateId: state.templateId,
        variantId: state.variantId,
        effectiveTrainingMaxes: const {},
        weeks: [
          GeneratedWeek(
            number: 1,
            sessions: [
              GeneratedSession(
                id: 'generated-w1-s1',
                date: DateTime(2026, 7, 21),
                movementId: const MovementId('session'),
                blocks: const [],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
