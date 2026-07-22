import 'package:flutter/material.dart';

import '../../../../generator_web/design/hybrid_generator_design.dart';

@immutable
class CycleFrequencyView {
  const CycleFrequencyView({required this.value, required this.label});

  final int value;
  final String label;
}

@immutable
class CycleSessionTokenView {
  const CycleSessionTokenView({
    required this.key,
    required this.label,
    this.semanticLabel,
  });

  final String key;
  final String label;
  final String? semanticLabel;
}

@immutable
class CycleSchedulingViewModel {
  const CycleSchedulingViewModel({
    required this.frequency,
    required this.allowedFrequencies,
    required this.sessions,
    required this.startDate,
    this.canMoveSessionLeft = const {},
    this.canMoveSessionRight = const {},
    this.bastardWorkOrder,
    this.weekOrder351,
  });

  final int frequency;
  final List<CycleFrequencyView> allowedFrequencies;
  final List<CycleSessionTokenView> sessions;
  final DateTime? startDate;
  final Set<String> canMoveSessionLeft;
  final Set<String> canMoveSessionRight;
  final bool? bastardWorkOrder;
  final bool? weekOrder351;
}

class CycleSchedulingBlock extends StatelessWidget {
  const CycleSchedulingBlock({
    required this.viewModel,
    this.onFrequencyChanged,
    this.onMoveSessionLeft,
    this.onMoveSessionRight,
    this.onStartDateChanged,
    this.onBastardWorkOrderChanged,
    this.onWeekOrder351Changed,
    this.title = 'SCHEDULING',
    this.frequencyLabel = 'Days a week',
    this.sessionOrderLabel = 'Lifts order',
    this.startDateLabel = 'Start date',
    this.bastardWorkOrderLabel = 'Bastard work order',
    this.weekOrder351Label = '3/5/1 week order',
    this.moveLeftTooltip = 'Move earlier',
    this.moveRightTooltip = 'Move later',
    super.key,
  });

  final CycleSchedulingViewModel viewModel;
  final ValueChanged<int>? onFrequencyChanged;
  final ValueChanged<String>? onMoveSessionLeft;
  final ValueChanged<String>? onMoveSessionRight;
  final ValueChanged<DateTime>? onStartDateChanged;
  final ValueChanged<bool>? onBastardWorkOrderChanged;
  final ValueChanged<bool>? onWeekOrder351Changed;
  final String title;
  final String frequencyLabel;
  final String sessionOrderLabel;
  final String startDateLabel;
  final String bastardWorkOrderLabel;
  final String weekOrder351Label;
  final String moveLeftTooltip;
  final String moveRightTooltip;

  @override
  Widget build(BuildContext context) => HybridGeneratorCard(
    title: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FrequencyRow(
          label: frequencyLabel,
          value: viewModel.frequency,
          allowed: viewModel.allowedFrequencies,
          onChanged: onFrequencyChanged,
        ),
        const SizedBox(height: 12),
        _SessionOrderRow(
          label: sessionOrderLabel,
          sessions: viewModel.sessions,
          canMoveLeft: viewModel.canMoveSessionLeft,
          canMoveRight: viewModel.canMoveSessionRight,
          onMoveLeft: onMoveSessionLeft,
          onMoveRight: onMoveSessionRight,
          moveLeftTooltip: moveLeftTooltip,
          moveRightTooltip: moveRightTooltip,
        ),
        if (viewModel.startDate != null) ...[
          const Divider(height: 24),
          _DateRow(
            label: startDateLabel,
            value: viewModel.startDate!,
            onChanged: onStartDateChanged,
          ),
        ],
        if (viewModel.bastardWorkOrder != null) ...[
          const Divider(height: 20),
          _OptionSwitch(
            key: const Key('cycle-scheduling-bastard-order'),
            label: bastardWorkOrderLabel,
            value: viewModel.bastardWorkOrder!,
            onChanged: onBastardWorkOrderChanged,
          ),
        ],
        if (viewModel.weekOrder351 != null)
          _OptionSwitch(
            key: const Key('cycle-scheduling-week-order-351'),
            label: weekOrder351Label,
            value: viewModel.weekOrder351!,
            onChanged: onWeekOrder351Changed,
          ),
      ],
    ),
  );
}

class _FrequencyRow extends StatelessWidget {
  const _FrequencyRow({
    required this.label,
    required this.value,
    required this.allowed,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<CycleFrequencyView> allowed;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = allowed.where((item) => item.value == value);
    final display = selected.isEmpty ? '$value' : selected.first.label;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(label),
        if (allowed.length <= 1)
          Text(
            display,
            key: const Key('cycle-scheduling-frequency-locked'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          )
        else
          SegmentedButton<int>(
            key: const Key('cycle-scheduling-frequency'),
            showSelectedIcon: false,
            segments: [
              for (final item in allowed)
                ButtonSegment(value: item.value, label: Text(item.label)),
            ],
            selected: {value},
            onSelectionChanged: onChanged == null
                ? null
                : (selection) => onChanged!(selection.single),
          ),
      ],
    );
  }
}

class _SessionOrderRow extends StatelessWidget {
  const _SessionOrderRow({
    required this.label,
    required this.sessions,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.moveLeftTooltip,
    required this.moveRightTooltip,
  });

  final String label;
  final List<CycleSessionTokenView> sessions;
  final Set<String> canMoveLeft;
  final Set<String> canMoveRight;
  final ValueChanged<String>? onMoveLeft;
  final ValueChanged<String>? onMoveRight;
  final String moveLeftTooltip;
  final String moveRightTooltip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final session in sessions)
            _SessionToken(
              session: session,
              canMoveLeft: canMoveLeft.contains(session.key),
              canMoveRight: canMoveRight.contains(session.key),
              onMoveLeft: onMoveLeft,
              onMoveRight: onMoveRight,
              moveLeftTooltip: moveLeftTooltip,
              moveRightTooltip: moveRightTooltip,
            ),
        ],
      ),
    ],
  );
}

class _SessionToken extends StatelessWidget {
  const _SessionToken({
    required this.session,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.moveLeftTooltip,
    required this.moveRightTooltip,
  });

  final CycleSessionTokenView session;
  final bool canMoveLeft;
  final bool canMoveRight;
  final ValueChanged<String>? onMoveLeft;
  final ValueChanged<String>? onMoveRight;
  final String moveLeftTooltip;
  final String moveRightTooltip;

  @override
  Widget build(BuildContext context) => Semantics(
    label: session.semanticLabel ?? session.label,
    child: Container(
      key: ValueKey('cycle-scheduling-session-${session.key}'),
      decoration: BoxDecoration(
        color: HybridGeneratorTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canMoveLeft)
            IconButton(
              key: ValueKey('cycle-scheduling-left-${session.key}'),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              padding: EdgeInsets.zero,
              tooltip: moveLeftTooltip,
              onPressed: onMoveLeft == null
                  ? null
                  : () => onMoveLeft!(session.key),
              icon: const Icon(Icons.chevron_left, size: 18),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Text(
              session.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (canMoveRight)
            IconButton(
              key: ValueKey('cycle-scheduling-right-${session.key}'),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              padding: EdgeInsets.zero,
              tooltip: moveRightTooltip,
              onPressed: onMoveRight == null
                  ? null
                  : () => onMoveRight!(session.key),
              icon: const Icon(Icons.chevron_right, size: 18),
            ),
        ],
      ),
    ),
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      Text(label),
      OutlinedButton.icon(
        key: const Key('cycle-scheduling-start-date'),
        onPressed: onChanged == null
            ? null
            : () async {
                final next = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (next != null) onChanged!(next);
              },
        icon: const Icon(Icons.calendar_today_outlined, size: 17),
        label: Text(
          '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}',
        ),
      ),
    ],
  );
}

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Switch(value: value, onChanged: onChanged),
    ],
  );
}
