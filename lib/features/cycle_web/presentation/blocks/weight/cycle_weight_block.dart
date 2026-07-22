import 'package:flutter/material.dart';

import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import '../../../../generator_web/design/hybrid_generator_design.dart';
import '../../../application/cycle_web_contract.dart';

typedef MovementMaxInputChanged =
    void Function(String movementId, CycleMovementMaxInput input);

/// Catalogue-agnostic editor for the main movement maxes.
///
/// This widget only presents values already expressed by [CycleEditorState].
/// Estimation, training-max and plating calculations stay in the application
/// and domain layers.
class CycleWeightBlock extends StatelessWidget {
  const CycleWeightBlock({
    required this.state,
    required this.movementIds,
    required this.onMaxInputKindChanged,
    required this.onMovementInputChanged,
    required this.onGlobalTrainingMaxRatioChanged,
    required this.onUnitChanged,
    super.key,
  });

  final CycleEditorState state;
  final List<String> movementIds;
  final ValueChanged<CycleMaxInputKind> onMaxInputKindChanged;
  final MovementMaxInputChanged onMovementInputChanged;
  final ValueChanged<int> onGlobalTrainingMaxRatioChanged;
  final ValueChanged<WeightUnit> onUnitChanged;

  CycleMaxInputKind get _selectedKind {
    for (final movementId in movementIds) {
      final kind = state.maxInputs[movementId]?.kind;
      if (kind != null) return kind;
    }
    return CycleMaxInputKind.oneRepMax;
  }

  @override
  Widget build(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    return Semantics(
      container: true,
      label: isFrench ? 'Charges principales' : 'Main movement weights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<CycleMaxInputKind>(
            key: const Key('cycle-web-max-mode'),
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6),
              ),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: CycleMaxInputKind.oneRepMax,
                label: Text('1 RM'),
              ),
              ButtonSegment(
                value: CycleMaxInputKind.directTrainingMax,
                label: Text('Training Max'),
              ),
              ButtonSegment(
                value: CycleMaxInputKind.repMax,
                label: Text('Rep Max'),
              ),
            ],
            selected: {_selectedKind},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onMaxInputKindChanged(selection.single);
              }
            },
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < movementIds.length; index++) ...[
            _MovementMaxRow(
              movementId: movementIds[index],
              input:
                  state.maxInputs[movementIds[index]] ??
                  CycleMovementMaxInput(
                    kind: _selectedKind,
                    weightCentiUnits: 0,
                    repetitions: _selectedKind == CycleMaxInputKind.repMax
                        ? 1
                        : null,
                  ),
              unit: state.unit,
              onChanged: (input) =>
                  onMovementInputChanged(movementIds[index], input),
            ),
            if (index != movementIds.length - 1) const SizedBox(height: 10),
          ],
          const Divider(height: 26),
          _Footer(
            ratioBasisPoints: state.globalTrainingMaxRatioBasisPoints,
            unit: state.unit,
            onRatioChanged: onGlobalTrainingMaxRatioChanged,
            onUnitChanged: onUnitChanged,
          ),
        ],
      ),
    );
  }
}

class _MovementMaxRow extends StatelessWidget {
  const _MovementMaxRow({
    required this.movementId,
    required this.input,
    required this.unit,
    required this.onChanged,
  });

  final String movementId;
  final CycleMovementMaxInput input;
  final WeightUnit unit;
  final ValueChanged<CycleMovementMaxInput> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 340;
      final markerAndName = Row(
        children: [
          const SizedBox(
            width: 30,
            child: Icon(Icons.fitness_center, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _humanize(movementId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
      final controls = _MaxControls(
        movementId: movementId,
        input: input,
        unit: unit,
        onChanged: onChanged,
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            markerAndName,
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: controls),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: markerAndName),
          const SizedBox(width: 8),
          controls,
        ],
      );
    },
  );

  String _humanize(String value) {
    final spaced = value.replaceAll('_', ' ').trim();
    return spaced.isEmpty
        ? value
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

class _MaxControls extends StatelessWidget {
  const _MaxControls({
    required this.movementId,
    required this.input,
    required this.unit,
    required this.onChanged,
  });

  final String movementId;
  final CycleMovementMaxInput input;
  final WeightUnit unit;
  final ValueChanged<CycleMovementMaxInput> onChanged;

  @override
  Widget build(BuildContext context) {
    final showsRepetitions = input.kind != CycleMaxInputKind.directTrainingMax;
    final editsRepetitions = input.kind == CycleMaxInputKind.repMax;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showsRepetitions) ...[
          SizedBox(
            width: 46,
            child: editsRepetitions
                ? _CompactNumberField(
                    fieldKey: 'cycle-web-max-reps-$movementId',
                    value: (input.repetitions ?? 1).toDouble(),
                    semanticLabel: 'Repetitions for ${_label(movementId)}',
                    decimals: 0,
                    onChanged: (value) => onChanged(
                      CycleMovementMaxInput(
                        kind: input.kind,
                        weightCentiUnits: input.weightCentiUnits,
                        repetitions: value.round().clamp(1, 999),
                      ),
                    ),
                  )
                : const _FixedRepetition(),
          ),
          const SizedBox(width: 7),
          const Text('rep ×', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 7),
        ],
        SizedBox(
          width: 66,
          child: _CompactNumberField(
            fieldKey: 'cycle-web-max-weight-$movementId',
            value: input.weightCentiUnits / 100,
            semanticLabel: 'Weight for ${_label(movementId)}',
            onChanged: (value) => onChanged(
              CycleMovementMaxInput(
                kind: input.kind,
                weightCentiUnits: (value * 100).round(),
                repetitions: input.repetitions,
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(width: 20, child: Text(unit.name)),
      ],
    );
  }

  String _label(String value) => value.replaceAll('_', ' ');
}

class _FixedRepetition extends StatelessWidget {
  const _FixedRepetition();

  @override
  Widget build(BuildContext context) => Semantics(
    label: '1 repetition',
    readOnly: true,
    child: Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        '1',
        style: TextStyle(
          color: HybridGeneratorTokens.background,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.ratioBasisPoints,
    required this.unit,
    required this.onRatioChanged,
    required this.onUnitChanged,
  });

  final int ratioBasisPoints;
  final WeightUnit unit;
  final ValueChanged<int> onRatioChanged;
  final ValueChanged<WeightUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(isFrench ? 'Ratio Training Max' : 'Training Max Ratio'),
            SizedBox(
              width: 54,
              child: _CompactNumberField(
                fieldKey: 'cycle-web-global-ratio',
                value: ratioBasisPoints / 100,
                semanticLabel: isFrench
                    ? 'Ratio Training Max en pourcentage'
                    : 'Training Max ratio percentage',
                onChanged: (value) => onRatioChanged((value * 100).round()),
              ),
            ),
            const Text('%'),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(isFrench ? 'Unité' : 'Unit'),
            SizedBox(
              width: 116,
              child: SegmentedButton<WeightUnit>(
                key: const Key('cycle-web-unit'),
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ],
                selected: {unit},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) onUnitChanged(selection.single);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactNumberField extends StatelessWidget {
  const _CompactNumberField({
    required this.fieldKey,
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
    this.decimals = 2,
  });

  final String fieldKey;
  final double value;
  final String semanticLabel;
  final ValueChanged<double> onChanged;
  final int decimals;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: semanticLabel,
    child: TextFormField(
      key: ValueKey(fieldKey),
      initialValue: _format(value),
      style: const TextStyle(
        color: HybridGeneratorTokens.background,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 12),
      ),
      onChanged: (text) {
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed != null && parsed >= 0) onChanged(parsed);
      },
    ),
  );

  String _format(double number) {
    if (number == number.roundToDouble()) return '${number.round()}';
    var text = number.toStringAsFixed(decimals);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }
}
