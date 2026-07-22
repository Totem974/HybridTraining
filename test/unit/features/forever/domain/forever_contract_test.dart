import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';

void main() {
  group('Forever identity', () {
    test('definition identity and revision remain explicit value objects', () {
      const id = ForeverDefinitionId('leader_anchor_v1');
      const revision = ForeverDefinitionRevision(3);

      expect(id.value, 'leader_anchor_v1');
      expect(revision.value, 3);
    });

    test('revision rejects zero and negative values', () {
      expect(() => ForeverDefinitionRevision(0), throwsAssertionError);
      expect(() => ForeverDefinitionRevision(-1), throwsAssertionError);
    });

    test('cycle reference has a stable composite key', () {
      const reference = ForeverCycleReference(
        templateId: 'classic.standard',
        variantId: 'four_days',
      );

      expect(reference.key, 'classic.standard/four_days');
    });
  });

  group('Forever phases', () {
    test('all declarative phase roles are represented', () {
      expect(ForeverPhaseRole.values, const [
        ForeverPhaseRole.leader,
        ForeverPhaseRole.anchor,
        ForeverPhaseRole.transition,
        ForeverPhaseRole.deload,
        ForeverPhaseRole.test,
        ForeverPhaseRole.custom,
      ]);
    });

    test('phase and slot order is retained as a finite ordered sequence', () {
      final definition = _definition([
        _phase('leaders', [
          _slot('leader-1', ForeverPhaseRole.leader, repeatCount: 2),
          _slot('deload', ForeverPhaseRole.deload),
        ]),
        _phase('anchor-and-test', [
          _slot('anchor', ForeverPhaseRole.anchor),
          _slot('tm-test', ForeverPhaseRole.test),
        ]),
      ]);

      expect(definition.phases.map((phase) => phase.id), [
        'leaders',
        'anchor-and-test',
      ]);
      expect(
        definition.phases.expand((phase) => phase.slots).map((slot) => slot.id),
        ['leader-1', 'deload', 'anchor', 'tm-test'],
      );
      expect(definition.phases.first.slots.first.repeatCount, 2);
    });

    test('optional is explicit and defaults to false', () {
      final requiredSlot = _slot('leader', ForeverPhaseRole.leader);
      final optionalSlot = _slot(
        'transition',
        ForeverPhaseRole.transition,
        optional: true,
      );

      expect(requiredSlot.optional, isFalse);
      expect(optionalSlot.optional, isTrue);
    });
  });

  test('Forever domain contract has no forbidden infrastructure imports', () {
    final source = File(
      'lib/features/forever/domain/forever_contract.dart',
    ).readAsStringSync();
    final imports = RegExp(
      r'''^import\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)!.toLowerCase()).toList();

    final forbiddenImports = imports.where(
      (path) =>
          path.startsWith('package:flutter/') ||
          path.contains('sqflite') ||
          path.contains('sqlite') ||
          path.contains('legacy') ||
          path.contains('poc_531'),
    );

    expect(forbiddenImports, isEmpty);
  });
}

ResolvedForeverDefinition _definition(List<ForeverPhase> phases) {
  const id = ForeverDefinitionId('leader_anchor_v1');
  const revision = ForeverDefinitionRevision(1);
  return ResolvedForeverDefinition(
    id: id,
    revision: revision,
    labelEn: 'Leader and anchor',
    labelFr: 'Leader et anchor',
    sourceRuleIds: const ['source.rule.1'],
    phases: phases,
    editorSchema: const ForeverEditorSchema(
      definitionId: id,
      revision: revision,
      configurableSlotIds: ['leader-1', 'anchor'],
    ),
  );
}

ForeverPhase _phase(String id, List<ForeverCycleSlot> slots) =>
    ForeverPhase(id: id, slots: slots);

ForeverCycleSlot _slot(
  String id,
  ForeverPhaseRole role, {
  int repeatCount = 1,
  bool optional = false,
}) {
  const cycle = ForeverCycleReference(
    templateId: 'classic.standard',
    variantId: 'four_days',
  );
  return ForeverCycleSlot(
    id: id,
    role: role,
    repeatCount: repeatCount,
    defaultCycle: cycle,
    allowedCycles: const [cycle],
    transition: const ForeverTransition(trainingMaxRule: KeepTrainingMax()),
    optional: optional,
  );
}
