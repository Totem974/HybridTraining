import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/forever_calculator/forever_calculator.dart';

void main() {
  group('Forever calculator catalogue', () {
    test('only FV-141 and FV-236 are selectable', () {
      expect(
        listForeverCalculatorTemplates(
          selectableOnly: true,
        ).map((template) => template.id),
        ['FV-141', 'FV-236'],
      );
      expect(
        listForeverCalculatorTemplates().where(
          (template) => !template.selectable,
        ),
        hasLength(4),
      );
    });

    test('FV-236 exposes the fixed reviewed Forever sequence', () {
      final template = selectForeverCalculatorTemplate('FV-236');
      expect(template.sequence.map((block) => block.kind), [
        ForeverBlockKind.leader,
        ForeverBlockKind.leader,
        ForeverBlockKind.seventhWeekDeload,
        ForeverBlockKind.anchor,
        ForeverBlockKind.seventhWeekTmTest,
      ]);
      expect(template.sequence.map((block) => block.startWeek), [
        1,
        4,
        7,
        8,
        11,
      ]);
      expect(
        template.trainingMaxPolicy,
        ForeverTrainingMaxPolicy.confirmAtCheckpoints,
      );
    });

    test('documentary entries cannot be selected', () {
      expect(
        () => selectForeverCalculatorTemplate('forever-documentary-bbb'),
        throwsStateError,
      );
      expect(
        () => selectForeverCalculatorTemplate('missing'),
        throwsArgumentError,
      );
    });

    test('template serialization is stable structured JSON', () {
      final decoded =
          jsonDecode(
                serializeForeverCalculatorTemplate(
                  selectForeverCalculatorTemplate('FV-236'),
                ),
              )
              as Map<String, dynamic>;
      expect(decoded['id'], 'FV-236');
      expect(decoded['sequence'], hasLength(5));
      expect(decoded['sources'], isNotEmpty);
    });
  });

  group('Forever calculator validation and generation', () {
    test('BPS accepts only its reviewed TM policies', () {
      final invalid = _configuration('FV-141', days: 3, ratio: .80);
      expect(
        validateForeverCalculatorConfiguration(
          invalid,
        ).map((issue) => issue.code),
        contains('bps_tm_ratio'),
      );
      expect(
        validateForeverCalculatorConfiguration(
          _configuration('FV-141', days: 3, ratio: .85),
        ),
        isEmpty,
      );
    });

    test('generation delegates deterministically to the reviewed Core v5', () {
      final configuration = _configuration(
        'FV-236',
        days: 4,
        ratio: .85,
        projectFutureTrainingMaxes: true,
      );
      final first = generateForeverCalculatorProgram(configuration);
      final second = generateForeverCalculatorProgram(configuration);
      expect(
        serializeForeverCalculatorProgram(first),
        serializeForeverCalculatorProgram(second),
      );
      expect(first.payload['blocks'], isNotEmpty);
      expect(
        deserializeForeverCalculatorProgram(
          serializeForeverCalculatorProgram(first),
        ).programId,
        'FV-236',
      );
    });

    test('rejects a non-Forever generation before Core generation', () {
      final configuration = ProgramConfiguration(
        programId: 'FV-236',
        generation: Generation.beyond,
        unit: WeightUnit.kilograms,
        lifts: _lifts,
        trainingMaxRatio: .85,
        daysPerWeek: 4,
        trainingWeekdays: const [1, 2, 4, 5],
        startDate: DateTime.utc(2026, 1, 5),
      );
      expect(
        validateForeverCalculatorConfiguration(configuration).single.code,
        'forever_generation_required',
      );
    });
  });
}

ProgramConfiguration _configuration(
  String id, {
  required int days,
  required double ratio,
  bool projectFutureTrainingMaxes = false,
}) => ProgramConfiguration(
  programId: id,
  generation: Generation.forever,
  unit: WeightUnit.kilograms,
  lifts: _lifts,
  trainingMaxRatio: ratio,
  daysPerWeek: days,
  trainingWeekdays: days == 3 ? const [1, 3, 5] : const [1, 2, 4, 5],
  options: GenerationSpecificOptions(
    projectFutureTrainingMaxes: projectFutureTrainingMaxes,
  ),
  startDate: DateTime.utc(2026, 1, 5),
);

const _lifts = {
  MainLift.overheadPress: LiftInput(
    lift: MainLift.overheadPress,
    kind: LiftInputKind.oneRepMax,
    weight: 60,
  ),
  MainLift.benchPress: LiftInput(
    lift: MainLift.benchPress,
    kind: LiftInputKind.oneRepMax,
    weight: 100,
  ),
  MainLift.squat: LiftInput(
    lift: MainLift.squat,
    kind: LiftInputKind.oneRepMax,
    weight: 140,
  ),
  MainLift.deadlift: LiftInput(
    lift: MainLift.deadlift,
    kind: LiftInputKind.oneRepMax,
    weight: 180,
  ),
};
