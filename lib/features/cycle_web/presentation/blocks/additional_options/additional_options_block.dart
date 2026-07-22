import 'package:flutter/material.dart';

import '../../../../generator_web/design/hybrid_generator_design.dart';

/// A catalogue-labelled group of option controls.
///
/// This presentation model deliberately carries no template or training
/// semantics. The application layer decides which controls belong together
/// and supplies their localized labels and widgets.
class AdditionalOptionGroup {
  const AdditionalOptionGroup({
    required this.id,
    required this.label,
    required this.children,
  });

  final String id;
  final String label;
  final List<Widget> children;
}

/// Reference-style layout for the catalogue-driven additional options.
///
/// [primaryGroups] is intended for the three prominent groups supplied by the
/// editor schema (for example warm-up, joker sets and deload). Any remaining
/// catalogue groups belong in [secondaryGroups] and are rendered on a distinct
/// row. No group is inferred from an option id in this widget.
class AdditionalOptionsBlock extends StatelessWidget {
  const AdditionalOptionsBlock({
    required this.title,
    required this.primaryGroups,
    this.secondaryGroups = const [],
    this.emptyLabel,
    this.desktopContentBreakpoint = 720,
    super.key,
  }) : assert(primaryGroups.length <= 3);

  final String title;
  final List<AdditionalOptionGroup> primaryGroups;
  final List<AdditionalOptionGroup> secondaryGroups;
  final String? emptyLabel;

  /// The available width inside the card, rather than the viewport width.
  final double desktopContentBreakpoint;

  @override
  Widget build(BuildContext context) => HybridGeneratorCard(
    title: title,
    child: Semantics(
      container: true,
      label: title,
      child: primaryGroups.isEmpty && secondaryGroups.isEmpty
          ? Text(emptyLabel ?? '')
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop =
                    constraints.maxWidth >= desktopContentBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GroupRow(
                      groups: primaryGroups,
                      desktop: desktop,
                      rowKey: const Key('additional-options-primary-row'),
                    ),
                    if (primaryGroups.isNotEmpty && secondaryGroups.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Divider(height: 1),
                      ),
                    if (secondaryGroups.isNotEmpty)
                      _GroupRow(
                        groups: secondaryGroups,
                        desktop: desktop,
                        rowKey: const Key('additional-options-secondary-row'),
                      ),
                  ],
                );
              },
            ),
    ),
  );
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.groups,
    required this.desktop,
    required this.rowKey,
  });

  final List<AdditionalOptionGroup> groups;
  final bool desktop;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Column(
        key: rowKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < groups.length; index++) ...[
            if (index > 0) const SizedBox(height: HybridGeneratorTokens.gap),
            _OptionGroup(group: groups[index]),
          ],
        ],
      );
    }

    return Row(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) const SizedBox(width: HybridGeneratorTokens.gap),
          Expanded(child: _OptionGroup(group: groups[index])),
        ],
      ],
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.group});

  final AdditionalOptionGroup group;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('additional-options-group-${group.id}'),
    container: true,
    label: group.label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          group.label.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HybridGeneratorTokens.text,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        if (group.children.isNotEmpty)
          const SizedBox(height: HybridGeneratorTokens.compactGap),
        for (var index = 0; index < group.children.length; index++) ...[
          if (index > 0)
            const SizedBox(height: HybridGeneratorTokens.compactGap),
          group.children[index],
        ],
      ],
    ),
  );
}
