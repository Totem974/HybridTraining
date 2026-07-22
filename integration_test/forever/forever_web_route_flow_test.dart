import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_contract.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_route.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('deep-linked Forever route generates, saves and reloads', (
    tester,
  ) async {
    final application = _IntegrationApplication();
    final route = ForeverWebRoute.build(
      settings: const RouteSettings(name: '/forever'),
      application: application,
    );
    await tester.pumpWidget(
      MaterialApp(home: Navigator(onGenerateRoute: (_) => route)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('forever-tm-squat')), '100');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forever-generate')));
    await tester.tap(find.byKey(const Key('forever-generate')));
    await tester.pumpAndSettle();

    expect(application.saved, isTrue);
    expect(application.generated, isTrue);
    expect(find.text('Macrocycle saved and reloaded'), findsOneWidget);
    expect(find.byKey(const Key('forever-node-0')), findsOneWidget);
  });
}

final class _IntegrationApplication implements ForeverWebApplication {
  bool saved = false;
  bool generated = false;

  @override
  Future<List<ForeverDefinitionItem>> loadDefinitions() async => const [
    ForeverDefinitionItem(
      id: 'integration-forever',
      revision: 1,
      labelEn: 'Leader / Anchor',
      labelFr: 'Leader / Ancre',
      movementIds: ['squat'],
      phases: [
        ForeverPhaseItem(
          id: 'main',
          slots: [
            ForeverSlotItem(
              id: 'leader',
              role: 'leader',
              repeatCount: 1,
              defaultCycleKey: 'bbb/original',
              allowedCycles: [
                ForeverCycleChoice(key: 'bbb/original', label: 'BBB'),
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
  Future<void> saveDraft(ForeverEditorDraft draft) async => saved = true;

  @override
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  ) async {
    generated = true;
    return GeneratedMacrocycleView(
      id: 'integration-macrocycle',
      state: 'scheduled',
      wasReloaded: true,
      nodes: [
        GeneratedMacrocycleNodeView(
          index: 0,
          role: 'leader',
          cycleLabel: 'BBB',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 21),
          trainingMaxesBefore: draft.trainingMaxCentiUnits,
          trainingMaxesAfter: const {'squat': 10500},
          weeks: const [
            ForeverCycleWeekView(number: 1, sessions: ['Squat']),
          ],
        ),
      ],
    );
  }
}
