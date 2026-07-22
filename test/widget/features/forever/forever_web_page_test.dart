import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_contract.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_page.dart';

void main() {
  testWidgets('edits a catalog-driven timeline and reloads the saved result', (
    tester,
  ) async {
    final application = _FakeForeverWebApplication();
    await tester.pumpWidget(_app(application));
    await tester.pumpAndSettle();

    expect(find.text('Forever generator'), findsOneWidget);
    expect(find.text('Leader'), findsNWidgets(2));
    expect(find.text('Deload'), findsOneWidget);
    expect(find.text('TM Test'), findsWidgets);

    await tester.tap(find.byKey(const Key('forever-slot-leader')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBB').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('forever-tm-squat')), '120');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forever-generate')));
    await tester.tap(find.byKey(const Key('forever-generate')));
    await tester.pumpAndSettle();

    expect(application.generatedDrafts, hasLength(1));
    expect(
      application.generatedDrafts.single.trainingMaxCentiUnits['squat'],
      12000,
    );
    expect(
      application.generatedDrafts.single.selectedCyclesBySlot['leader'],
      'bbb/original',
    );
    expect(find.text('Macrocycle saved and reloaded'), findsOneWidget);
    expect(find.byKey(const Key('forever-node-0')), findsOneWidget);
  });

  testWidgets('is responsive, French and exposes accessible actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_app(_FakeForeverWebApplication(), french: true));
    await tester.pumpAndSettle();

    expect(find.text('Générateur Forever'), findsOneWidget);
    expect(find.text('Training Max initiaux'), findsOneWidget);
    expect(find.text('Générer et sauvegarder'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('forever-generate'))),
      matchesSemantics(
        label: 'Générer et sauvegarder le macrocycle',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('desktop layout keeps the full editor usable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeForeverWebApplication()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forever-definition')), findsOneWidget);
    expect(find.byKey(const Key('forever-slot-leader')), findsOneWidget);
    expect(find.byKey(const Key('forever-tm-squat')), findsOneWidget);
    expect(find.byKey(const Key('forever-generate')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(ForeverWebApplication application, {bool french = false}) =>
    MaterialApp(
      locale: Locale(french ? 'fr' : 'en'),
      supportedLocales: const [Locale('en'), Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ForeverWebPage(application: application),
    );

final class _FakeForeverWebApplication implements ForeverWebApplication {
  final savedDrafts = <ForeverEditorDraft>[];
  final generatedDrafts = <ForeverEditorDraft>[];

  @override
  Future<List<ForeverDefinitionItem>> loadDefinitions() async => const [
    ForeverDefinitionItem(
      id: 'leader_anchor',
      revision: 1,
      labelEn: 'Leader / Anchor',
      labelFr: 'Leader / Ancre',
      movementIds: ['squat'],
      phases: [
        ForeverPhaseItem(
          id: 'leaders',
          slots: [
            ForeverSlotItem(
              id: 'leader',
              role: 'leader',
              repeatCount: 2,
              defaultCycleKey: 'standard/fsl',
              allowedCycles: [
                ForeverCycleChoice(key: 'standard/fsl', label: 'FSL'),
                ForeverCycleChoice(key: 'bbb/original', label: 'BBB'),
              ],
            ),
          ],
        ),
        ForeverPhaseItem(
          id: 'finish',
          slots: [
            ForeverSlotItem(
              id: 'deload',
              role: 'deload',
              repeatCount: 1,
              defaultCycleKey: 'protocol/deload',
              allowedCycles: [
                ForeverCycleChoice(
                  key: 'protocol/deload',
                  label: '7th Week Deload',
                ),
              ],
            ),
            ForeverSlotItem(
              id: 'anchor',
              role: 'anchor',
              repeatCount: 1,
              defaultCycleKey: 'standard/pr',
              allowedCycles: [
                ForeverCycleChoice(key: 'standard/pr', label: 'PR Set'),
              ],
            ),
            ForeverSlotItem(
              id: 'test',
              role: 'test',
              repeatCount: 1,
              defaultCycleKey: 'protocol/tm_test',
              allowedCycles: [
                ForeverCycleChoice(key: 'protocol/tm_test', label: 'TM Test'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Future<ForeverEditorDraft?> loadDraft() async => null;

  @override
  Future<GeneratedMacrocycleView?> loadSavedMacrocycle() async => null;

  @override
  Future<void> saveDraft(ForeverEditorDraft draft) async {
    savedDrafts.add(draft);
  }

  @override
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  ) async {
    generatedDrafts.add(draft);
    return GeneratedMacrocycleView(
      id: 'macro-1',
      state: 'scheduled',
      wasReloaded: true,
      nodes: [
        GeneratedMacrocycleNodeView(
          index: 0,
          role: 'leader',
          cycleLabel: 'FSL',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 21),
          trainingMaxesBefore: const {'squat': 12000},
          trainingMaxesAfter: const {'squat': 12500},
          weeks: const [
            ForeverCycleWeekView(number: 1, sessions: ['Squat', 'Press']),
          ],
        ),
      ],
    );
  }
}
