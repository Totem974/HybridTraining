import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/forever/domain/forever_architecture.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';

void main() {
  group('user-defined architecture editing', () {
    test('adds, reorders, duplicates and removes nodes immutably', () {
      final original = _architecture([
        _node('leader', ForeverPhaseRole.leader),
      ]);
      final added = original.add(_node('anchor', ForeverPhaseRole.anchor));
      final reordered = added.reorder('anchor', 0);
      final duplicated = reordered.duplicate('anchor', newId: 'anchor-copy');
      final removed = duplicated.remove('anchor-copy');

      expect(original.nodes.map((node) => node.id), ['leader']);
      expect(added.nodes.map((node) => node.id), ['leader', 'anchor']);
      expect(reordered.nodes.map((node) => node.id), ['anchor', 'leader']);
      expect(duplicated.nodes.map((node) => node.id), [
        'anchor',
        'anchor-copy',
        'leader',
      ]);
      expect(removed.nodes.map((node) => node.id), ['anchor', 'leader']);
    });

    test('copies the complete configuration without changing the source', () {
      final sourceConfiguration = _configuration('classic.bbb', 'leader');
      final architecture = _architecture([
        _node(
          'leader',
          ForeverPhaseRole.leader,
          configuration: sourceConfiguration,
        ),
        _node(
          'anchor',
          ForeverPhaseRole.anchor,
          configuration: _configuration('classic.standard', 'anchor'),
        ),
      ]);

      final copied = architecture.copyConfiguration(
        fromNodeId: 'leader',
        toNodeId: 'anchor',
      );

      expect(copied.nodes[1].configuration, same(sourceConfiguration));
      expect(
        architecture.nodes[1].configuration!.cycle.templateId,
        'classic.standard',
      );
      expect(copied.nodes[1].configuration!.supplemental, {'id': 'fsl'});
      expect(copied.nodes[1].configuration!.assistance, {'preset': 'basic'});
      expect(copied.nodes[1].configuration!.conditioning, {'days': 2});
    });

    test('protects required nodes and finite non-empty sequence', () {
      final required = _architecture([
        _node('leader', ForeverPhaseRole.leader, required: true),
      ]);
      final optional = _architecture([
        _node('leader', ForeverPhaseRole.leader),
      ]);

      expect(
        () => required.remove('leader'),
        throwsA(
          isA<ForeverArchitectureException>().having(
            (error) => error.issue.code,
            'code',
            ForeverArchitectureIssueCode.requiredNodeRemoval,
          ),
        ),
      );
      expect(
        () => optional.remove('leader'),
        throwsA(
          isA<ForeverArchitectureException>().having(
            (error) => error.issue.code,
            'code',
            ForeverArchitectureIssueCode.emptySequence,
          ),
        ),
      );
    });

    test('preset architecture cannot be structurally edited', () {
      final preset = ForeverArchitecture(
        id: 'preset',
        mode: ForeverArchitectureMode.preset,
        nodes: [_node('leader', ForeverPhaseRole.leader)],
        presetDefinitionId: const ForeverDefinitionId('published'),
        presetRevision: const ForeverDefinitionRevision(1),
        sourceRuleIds: const ['book.page'],
      );

      expect(
        () => preset.add(_node('anchor', ForeverPhaseRole.anchor)),
        throwsA(isA<ForeverArchitectureException>()),
      );
    });
  });

  group('architecture validation', () {
    test(
      'reports duplicate, missing configuration and role incompatibility',
      () {
        final architecture = _architecture([
          ForeverArchitectureNode(
            id: 'same',
            role: ForeverPhaseRole.leader,
            transition: _transition,
            allowedRoles: const [ForeverPhaseRole.anchor],
          ),
          _node('same', ForeverPhaseRole.anchor),
        ]);

        expect(
          architecture.validate().map((issue) => issue.code),
          containsAll([
            ForeverArchitectureIssueCode.unconfiguredCycle,
            ForeverArchitectureIssueCode.incompatibleRole,
            ForeverArchitectureIssueCode.duplicateNodeId,
          ]),
        );
      },
    );

    test('reports protocol orphan and incompatible cycle explicitly', () {
      final protocolOnly = _architecture([
        _node('test', ForeverPhaseRole.test),
      ]);
      final incompatible = _architecture([
        ForeverArchitectureNode(
          id: 'leader',
          role: ForeverPhaseRole.leader,
          transition: _transition,
          configuration: _configuration('classic.bbb', 'leader'),
          allowedCycles: const [
            ForeverCycleReference(
              templateId: 'classic.standard',
              variantId: 'anchor',
            ),
          ],
        ),
      ]);

      expect(
        protocolOnly.validate().map((issue) => issue.code),
        contains(ForeverArchitectureIssueCode.orphanProtocol),
      );
      expect(
        incompatible.validate().map((issue) => issue.code),
        contains(ForeverArchitectureIssueCode.incompatibleCycle),
      );
    });
  });

  test('converts custom architecture to existing composer contracts', () {
    final architecture = _architecture([
      _node('leader', ForeverPhaseRole.leader),
      _node('deload', ForeverPhaseRole.deload),
      _node('anchor', ForeverPhaseRole.anchor),
    ]);

    final definition = architecture.toResolvedDefinition();
    final request = architecture.toRequest(
      macrocycleId: 'macro-1',
      startDate: DateTime.utc(2026, 7, 22),
      initialTrainingMaxes: const {
        MovementId('squat'): Weight(10000, WeightUnit.lb),
      },
      unit: WeightUnit.lb,
      roundingIncrement: const Weight(500, WeightUnit.lb),
      barProfile: const BarProfile(
        weight: Weight(4500, WeightUnit.lb),
        platesPerSide: [Weight(4500, WeightUnit.lb)],
      ),
    );

    expect(definition.id.value, 'userDefined:custom');
    expect(definition.sourceRuleIds, ['userDefined']);
    expect(definition.phases.single.slots.map((slot) => slot.id), [
      'leader',
      'deload',
      'anchor',
    ]);
    expect(request.definitionId, definition.id);
    expect(request.slotRequests.keys, ['leader', 'deload', 'anchor']);
    expect(request.slotRequests['leader']!.cycle.templateId, 'classic.bbb');
  });

  test('domain architecture has no Flutter, SQLite or legacy dependency', () {
    final source = File(
      'lib/features/forever/domain/forever_architecture.dart',
    ).readAsStringSync().toLowerCase();
    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('sqlite')));
    expect(source, isNot(contains('legacy')));
  });
}

const _transition = ForeverTransition(trainingMaxRule: KeepTrainingMax());

ForeverArchitecture _architecture(List<ForeverArchitectureNode> nodes) =>
    ForeverArchitecture(
      id: 'custom',
      mode: ForeverArchitectureMode.userDefined,
      nodes: nodes,
    );

ForeverArchitectureNode _node(
  String id,
  ForeverPhaseRole role, {
  ForeverNodeConfiguration? configuration,
  bool required = false,
  List<ForeverPhaseRole> allowedRoles = ForeverPhaseRole.values,
}) => ForeverArchitectureNode(
  id: id,
  role: role,
  transition: _transition,
  configuration: configuration ?? _configuration('classic.bbb', id),
  required: required,
  allowedRoles: allowedRoles,
);

ForeverNodeConfiguration _configuration(String template, String variant) =>
    ForeverNodeConfiguration(
      cycle: ForeverCycleReference(templateId: template, variantId: variant),
      trainingDays: const [1, 3, 5],
      sessionOrder: const [MovementId('squat')],
      parameters: const {'joker': true},
      warmUp: const {'enabled': true},
      joker: const {'enabled': true},
      deload: const {'protocol': 'seventh-week'},
      supplemental: const {'id': 'fsl'},
      assistance: const {'preset': 'basic'},
      conditioning: const {'days': 2},
      scheduleId: 'three-days',
    );
