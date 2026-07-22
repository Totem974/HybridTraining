import 'package:flutter/material.dart';

import '../../../../generator_web/design/hybrid_generator_design.dart';

@immutable
class CyclePlateDenominationView {
  const CyclePlateDenominationView({
    required this.centiUnits,
    required this.label,
    required this.count,
    this.canAdd = true,
    this.canRemove = true,
  });

  final int centiUnits;
  final String label;
  final int count;
  final bool canAdd;
  final bool canRemove;
}

class CyclePlatingBlock extends StatelessWidget {
  const CyclePlatingBlock({
    required this.denominations,
    required this.barWeightLabel,
    required this.maximumWeightLabel,
    required this.onCountChanged,
    this.title = 'PLATING & BARBELL',
    this.barWeightCaption = 'Barbell weight',
    this.maximumWeightCaption = 'Maximum total weight',
    this.addTooltip = 'Add one plate',
    this.removeTooltip = 'Remove one plate',
    this.equipmentProfileLabel,
    super.key,
  });

  final List<CyclePlateDenominationView> denominations;
  final String title;
  final String barWeightCaption;
  final String barWeightLabel;
  final String maximumWeightCaption;
  final String maximumWeightLabel;
  final String addTooltip;
  final String removeTooltip;
  final String? equipmentProfileLabel;
  final void Function(int centiUnits, int count) onCountChanged;

  @override
  Widget build(BuildContext context) => HybridGeneratorCard(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (equipmentProfileLabel != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              equipmentProfileLabel!,
              key: const Key('cycle-plating-equipment-profile'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: HybridGeneratorTokens.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 420 ? 108.0 : 112.0;
            return Wrap(
              spacing: 8,
              runSpacing: 16,
              children: [
                for (final plate in denominations)
                  SizedBox(
                    width: itemWidth,
                    child: _PlateCounter(
                      plate: plate,
                      addTooltip: addTooltip,
                      removeTooltip: removeTooltip,
                      onCountChanged: onCountChanged,
                    ),
                  ),
              ],
            );
          },
        ),
        const Divider(height: 28),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runAlignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            _SummaryValue(
              key: const Key('cycle-plating-bar-weight'),
              caption: barWeightCaption,
              value: barWeightLabel,
            ),
            _SummaryValue(
              key: const Key('cycle-plating-maximum-weight'),
              caption: maximumWeightCaption,
              value: maximumWeightLabel,
              alignEnd: true,
            ),
          ],
        ),
      ],
    ),
  );
}

class _PlateCounter extends StatelessWidget {
  const _PlateCounter({
    required this.plate,
    required this.addTooltip,
    required this.removeTooltip,
    required this.onCountChanged,
  });

  final CyclePlateDenominationView plate;
  final String addTooltip;
  final String removeTooltip;
  final void Function(int centiUnits, int count) onCountChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${plate.label}: ${plate.count}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          plate.label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: ValueKey('cycle-plating-remove-${plate.centiUnits}'),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              padding: EdgeInsets.zero,
              tooltip: removeTooltip,
              onPressed: plate.count > 0 && plate.canRemove
                  ? () => onCountChanged(plate.centiUnits, plate.count - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
            ),
            SizedBox(
              width: 24,
              child: Text(
                '${plate.count}',
                key: ValueKey('cycle-plating-count-${plate.centiUnits}'),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: ValueKey('cycle-plating-add-${plate.centiUnits}'),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              padding: EdgeInsets.zero,
              tooltip: addTooltip,
              onPressed: plate.canAdd
                  ? () => onCountChanged(plate.centiUnits, plate.count + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline, size: 20),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.caption,
    required this.value,
    this.alignEnd = false,
    super.key,
  });

  final String caption;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(caption, style: Theme.of(context).textTheme.bodySmall),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}
