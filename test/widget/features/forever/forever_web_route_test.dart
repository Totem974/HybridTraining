import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_contract.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_page.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_route.dart';

void main() {
  test('only handles the /forever route', () {
    final application = _EmptyApplication();
    expect(
      ForeverWebRoute.build(
        settings: const RouteSettings(name: '/cycle'),
        application: application,
      ),
      isNull,
    );
    final route =
        ForeverWebRoute.build(
              settings: const RouteSettings(name: '/forever'),
              application: application,
            )
            as MaterialPageRoute<void>;
    expect(route.builder(_FakeBuildContext()), isA<ForeverWebPage>());
  });
}

final class _EmptyApplication implements ForeverWebApplication {
  @override
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  ) => throw UnimplementedError();
  @override
  Future<List<ForeverDefinitionItem>> loadDefinitions() async => const [];
  @override
  Future<ForeverEditorDraft?> loadDraft() async => null;
  @override
  Future<GeneratedMacrocycleView?> loadSavedMacrocycle() async => null;
  @override
  Future<void> saveDraft(ForeverEditorDraft draft) async {}
}

final class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
