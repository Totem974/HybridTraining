import 'package:flutter/material.dart';

import '../../../cycle_generation/domain/cycle_contract.dart';
import '../../../generator_web/design/hybrid_generator_design.dart';
import '../../application/cycle_web_contract.dart';

typedef CycleLabelResolver = String Function(String value);

/// Responsive, human-readable rendering of a generated Cycle.
class CycleProgram extends StatelessWidget {
  const CycleProgram({
    required this.view,
    required this.labelFor,
    required this.showPlating,
    this.isFrench = false,
    super.key,
  });

  final GeneratedCycleView view;
  final CycleLabelResolver labelFor;
  final bool showPlating;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: isFrench ? 'Programme généré' : 'Generated program',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final week in view.cycle.weeks) ...[
          Text(
            '${isFrench ? 'SEMAINE' : 'WEEK'} ${week.number}',
            key: ValueKey('cycle-program-week-${week.number}'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _SessionGrid(
            sessions: week.sessions,
            labelFor: labelFor,
            showPlating: showPlating,
            isFrench: isFrench,
          ),
          const SizedBox(height: HybridGeneratorTokens.gap),
        ],
      ],
    ),
  );
}

class _SessionGrid extends StatelessWidget {
  const _SessionGrid({
    required this.sessions,
    required this.labelFor,
    required this.showPlating,
    required this.isFrench,
  });

  final List<GeneratedSession> sessions;
  final CycleLabelResolver labelFor;
  final bool showPlating;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 760
          ? 4
          : constraints.maxWidth >= 480
          ? 2
          : 1;
      const gap = 12.0;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final session in sessions)
            SizedBox(
              width: width,
              child: _SessionCard(
                session: session,
                labelFor: labelFor,
                showPlating: showPlating,
                isFrench: isFrench,
              ),
            ),
        ],
      );
    },
  );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.labelFor,
    required this.showPlating,
    required this.isFrench,
  });

  final GeneratedSession session;
  final CycleLabelResolver labelFor;
  final bool showPlating;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('cycle-program-session-${session.id}'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: HybridGeneratorTokens.surfaceMuted.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          labelFor(session.movementId.value).toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          _date(session.date),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HybridGeneratorTokens.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (final block in session.blocks)
          _Block(
            block: block,
            labelFor: labelFor,
            showPlating: showPlating,
            isFrench: isFrench,
          ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.labelFor,
    required this.showPlating,
    required this.isFrench,
  });

  final GeneratedBlock block;
  final CycleLabelResolver labelFor;
  final bool showPlating;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _heading,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      for (final set in block.sets)
        _SetLine(set: set, showPlating: showPlating, isFrench: isFrench),
      const SizedBox(height: 8),
    ],
  );

  String get _heading {
    final role = labelFor(block.role);
    final movement = labelFor(block.movementId.value);
    return role.toLowerCase() == movement.toLowerCase()
        ? movement.toUpperCase()
        : '${role.toUpperCase()} · $movement';
  }
}

class _SetLine extends StatelessWidget {
  const _SetLine({
    required this.set,
    required this.showPlating,
    required this.isFrench,
  });

  final GeneratedSet set;
  final bool showPlating;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: HybridGeneratorTokens.background.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_repetitions(set.repetitions)} × ${_load(set.plannedLoad)}',
            key: ValueKey('cycle-program-set-${set.index}'),
          ),
        ),
        if (showPlating && set.platesPerSide.isNotEmpty)
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 3,
              runSpacing: 3,
              children: [
                for (final plate in set.platesPerSide)
                  _PlateChip(label: _weight(plate)),
              ],
            ),
          ),
      ],
    ),
  );

  String _load(Weight? load) => load == null
      ? (isFrench ? 'poids du corps' : 'bodyweight')
      : '${_weight(load)} ${load.unit.name}';

  String _weight(Weight value) {
    final number = value.value;
    return number == number.roundToDouble()
        ? '${number.round()}'
        : number.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  String _repetitions(Map<String, Object> value) {
    final type = value['type'];
    if (type == 'fixed') return '${value['count']}';
    if (type == 'range') return '${value['minimum']}–${value['maximum']}';
    if (type == 'total') {
      return '${value['total']} ${isFrench ? 'reps' : 'reps'}';
    }
    if (type == 'amrap') {
      final minimum = value['minimum'];
      return minimum == null ? 'AMRAP' : '$minimum+';
    }
    return isFrench ? 'Répétitions' : 'Repetitions';
  }
}

class _PlateChip extends StatelessWidget {
  const _PlateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('cycle-program-plate'),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: HybridGeneratorTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}
