import 'package:flutter/material.dart';

import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:training_engine/features/training_catalog/domain/catalog_index.dart';
import '../application/cycle_web_contract.dart';
import 'cycle_web_page.dart';

abstract final class CycleWebRoute {
  static const path = '/cycle';

  static Route<void>? build({
    required RouteSettings settings,
    required CycleWebApplication application,
    String foreverRoute = '/forever',
  }) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri == null || uri.path != path) return null;
    final templateId = uri.queryParameters['template'];
    final variantId = uri.queryParameters['variant'];
    final selectedApplication = templateId != null && variantId != null
        ? _DeepLinkedCycleWebApplication(
            delegate: application,
            templateId: templateId,
            variantId: variantId,
          )
        : application;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => CycleWebPage(
        application: selectedApplication,
        foreverRoute: foreverRoute,
      ),
    );
  }
}

final class _DeepLinkedCycleWebApplication implements CycleWebApplication {
  const _DeepLinkedCycleWebApplication({
    required this.delegate,
    required this.templateId,
    required this.variantId,
  });

  final CycleWebApplication delegate;
  final String templateId;
  final String variantId;

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) =>
      delegate.generate(state);

  @override
  Future<CycleEditorState?> loadDraft() async {
    final stored = await delegate.loadDraft();
    if (stored?.templateId == templateId && stored?.variantId == variantId) {
      return stored;
    }
    return CycleEditorState(templateId: templateId, variantId: variantId);
  }

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  }) => delegate.loadEditorSchema(templateId: templateId, variantId: variantId);

  @override
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  }) => delegate.loadMovementIds(templateId: templateId, variantId: variantId);

  @override
  Future<List<String>> loadSessionIds({
    required String templateId,
    required String variantId,
  }) => delegate.loadSessionIds(templateId: templateId, variantId: variantId);

  @override
  Future<CycleCatalogIndex> loadIndex() => delegate.loadIndex();

  @override
  Future<void> saveDraft(CycleEditorState state) => delegate.saveDraft(state);
}
