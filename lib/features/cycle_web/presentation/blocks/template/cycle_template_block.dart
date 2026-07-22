import 'package:flutter/material.dart';

import '../../../../training_catalog/domain/catalog_index.dart';
import '../../../../generator_web/design/hybrid_generator_design.dart';
import '../../../application/cycle_web_contract.dart';

typedef CycleTemplateLabelBuilder =
    String Function(CycleTemplateSummary template);
typedef CycleVariantLabelBuilder = String Function(String variantId);

/// Catalogue-driven template selector for the Cycle editor.
///
/// The widget only presents the available catalogue entries. Loading a new
/// schema and rendering its options remain the responsibility of its caller.
class CycleTemplateBlock extends StatelessWidget {
  const CycleTemplateBlock({
    required this.index,
    required this.state,
    required this.onTemplateSelected,
    required this.onVariantSelected,
    required this.templateLabelBuilder,
    required this.variantLabelBuilder,
    this.options,
    this.enabled = true,
    this.isFrench = false,
    super.key,
  });

  final CycleCatalogIndex index;
  final CycleEditorState state;
  final ValueChanged<String> onTemplateSelected;
  final ValueChanged<String> onVariantSelected;
  final CycleTemplateLabelBuilder templateLabelBuilder;
  final CycleVariantLabelBuilder variantLabelBuilder;
  final Widget? options;
  final bool enabled;
  final bool isFrench;

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = index.templates.firstWhere(
      (template) => template.id == state.templateId,
      orElse: () => index.templates.first,
    );
    final variants = selectedTemplate.variantIds;
    final selectedVariant = variants.contains(state.variantId)
        ? state.variantId
        : variants.firstOrNull;

    return HybridGeneratorCard(
      title: isFrench ? 'MODÈLE' : 'TEMPLATE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectionRow<CycleTemplateSummary>(
            rowKey: const Key('cycle-web-template'),
            label: isFrench ? 'Modèle' : 'Template',
            value: templateLabelBuilder(selectedTemplate),
            items: index.templates,
            itemValue: (template) => template.id,
            itemLabel: templateLabelBuilder,
            selectedValue: selectedTemplate.id,
            enabled: enabled,
            onSelected: onTemplateSelected,
          ),
          const Divider(height: 1),
          _SelectionRow<String>(
            rowKey: const Key('cycle-web-variant'),
            label: isFrench ? 'Variante' : 'Variant',
            value: selectedVariant == null
                ? '—'
                : variantLabelBuilder(selectedVariant),
            items: variants,
            itemValue: (variant) => variant,
            itemLabel: variantLabelBuilder,
            selectedValue: selectedVariant,
            enabled: enabled && selectedVariant != null,
            onSelected: onVariantSelected,
          ),
          if (options != null) ...[
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.only(top: 8), child: options!),
          ],
        ],
      ),
    );
  }
}

class _SelectionRow<T> extends StatelessWidget {
  const _SelectionRow({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.items,
    required this.itemValue,
    required this.itemLabel,
    required this.selectedValue,
    required this.enabled,
    required this.onSelected,
  });

  final Key rowKey;
  final String label;
  final String value;
  final List<T> items;
  final String Function(T item) itemValue;
  final String Function(T item) itemLabel;
  final String? selectedValue;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: value,
    button: true,
    enabled: enabled,
    child: PopupMenuButton<String>(
      key: rowKey,
      enabled: enabled,
      tooltip: label,
      initialValue: selectedValue,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: itemValue(item),
            child: Text(
              itemLabel(item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF181818)),
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: HybridGeneratorTokens.text,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: HybridGeneratorTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: enabled
                    ? HybridGeneratorTokens.text
                    : HybridGeneratorTokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
