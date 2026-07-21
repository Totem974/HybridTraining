import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/application/catalog_cycle_primitive_codec.dart';
import 'package:hybrid_training/features/cycle_generation/domain/catalog_cycle_primitives.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';

void main() {
  const codec = CatalogCyclePrimitiveCodec();

  test('decodes closed relative set positions without template knowledge', () {
    expect(
      codec.decodeRelativeSetLoad({
        'type': 'relativeSet',
        'position': 'first',
      }).position,
      RelativeSetPosition.first,
    );
    final top = codec.decodeRelativeSetLoad({
      'type': 'relativeSet',
      'position': 'top',
      'multiplierBasisPoints': 9000,
    });
    expect(top.position, RelativeSetPosition.top);
    expect(top.multiplierBasisPoints, 9000);
  });

  test('expands ordered finite phases deterministically', () {
    final phases = codec.decodePhases([
      {
        'id': 'accumulation',
        'repeatCount': 2,
        'weekPlans': [
          {
            'weekNumber': 1,
            'componentIds': [
              {'id': 'main', 'revision': 1},
            ],
          },
          {
            'weekNumber': 2,
            'componentIds': [
              {'id': 'supplemental', 'revision': 2},
            ],
          },
        ],
      },
    ]);
    final expanded = const PhaseExpander().expand(phases);
    expect(expanded.map((week) => week.number), [1, 2, 3, 4]);
    expect(expanded.map((week) => week.phaseIteration), [1, 1, 2, 2]);
    expect(expanded.map((week) => week.sourceWeekNumber), [1, 2, 1, 2]);
  });

  test('decodes closed execution techniques and runtime gates', () {
    expect(
      codec.decodeSetExecution({
        'type': 'restPause',
        'restSeconds': 20,
        'clusterRepetitions': 5,
      }).kind,
      SetExecutionKind.restPause,
    );
    expect(
      codec.decodeSetExecution({'type': 'paused', 'pauseSeconds': 2}).kind,
      SetExecutionKind.paused,
    );
    expect(
      codec.decodeSetExecution({
        'type': 'dynamic',
        'targetVelocity': 'fastWithPerfectForm',
      }).kind,
      SetExecutionKind.dynamic,
    );
    expect(
      codec.decodeRuntimeGate({
        'type': 'trainingMaxCheckpoint',
        'required': true,
      }).kind,
      RuntimeGateKind.trainingMaxCheckpoint,
    );
  });

  test('rejects unknown fields and incomplete technique payloads', () {
    expect(
      () => codec.decodeRelativeSetLoad({
        'type': 'relativeSet',
        'position': 'first',
        'templateId': 'forbidden',
      }),
      throwsFormatException,
    );
    expect(
      () => codec.decodeSetExecution({'type': 'restPause'}),
      throwsFormatException,
    );
    expect(
      () => codec.decodeRuntimeGate({'type': 'unknownGate', 'required': true}),
      throwsFormatException,
    );
  });
}
