const crypto = require('node:crypto');

const FIXTURE_SET_ID = 'source-calculator-v1';
const SOURCE_ARCHIVE_SHA256 =
  '6f9b3613d0ecc6a0ff18837308f74aecc4e9cf4f5cee0201de595152a404583f';

const EXPECTED_SCENARIO_IDS = Object.freeze([
  'bbb-original-4-day',
  'bbb-less-boring-4-day',
  'bbb-5x5-4-day',
  'bbb-5x3-4-day',
  'bbb-5x1-4-day',
  'bbb-beyond-variation-1-4-day',
  'bbb-beyond-variation-2-4-day',
  'bbb-2-day',
  'bbb-original-3-day',
  'fsl-amrap-4-day',
  'fsl-multiple-3x5-4-day',
  'fsl-multiple-5x8-4-day',
  'gvt-10x10-4-day',
  'gvt-10x10-alternate-4-day',
  'bbb-challenge-six-weeks',
  'bbb-challenge-six-weeks-same-lift',
  'bbb-challenge-three-months',
  'bbb-challenge-thirteen-weeks',
  'bbb-challenge-thirteen-weeks-kg',
  'full-body-original-phase-one',
  'full-body-updated-default',
  'full-body-full-boring-default',
]);

const EXPECTED_COVERAGE = Object.freeze([
  'bbb.variant.original',
  'bbb.variant.lessBoring',
  'bbb.variant.fiveByFive',
  'bbb.variant.fiveByThree',
  'bbb.variant.fiveByOne',
  'bbb.variant.beyondVariation1',
  'bbb.variant.beyondVariation2',
  'bbb.variant.twoDaysPerWeek',
  'fsl.mode.amrap',
  'fsl.mode.multipleSets.3x5',
  'fsl.mode.multipleSets.5x8',
  'gvt.10x10',
  'gvt.alternateExercise.enabled',
  'gvt.useSameRatio.enabled',
  'bbbChallenge.duration.sixWeeks',
  'bbbChallenge.lessBoring.disabled',
  'bbbChallenge.duration.threeMonths',
  'bbbChallenge.duration.thirteenWeeks',
  'bbbChallenge.tmIncrement.kg.upper2_5',
  'bbbChallenge.tmIncrement.kg.lower5',
  'fullBody.mode.original',
  'fullBody.mode.updated',
  'fullBody.mode.fullBoring',
  'schedule.frequency.two',
  'schedule.frequency.three',
  'schedule.frequency.four',
]);

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function stableStringify(value) {
  return JSON.stringify(sortValue(value));
}

function sortValue(value) {
  if (Array.isArray(value)) {
    return value.map(sortValue);
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, sortValue(value[key])]),
    );
  }
  return value;
}

function outputSha256(output) {
  return sha256(stableStringify(output.weeks));
}

function corpusSha256(scenarios) {
  return sha256(
    stableStringify(
      scenarios.map((scenario) => ({
        id: scenario.id,
        coverage: scenario.coverage,
        input: scenario.input,
        selectedState: scenario.selectedState,
        outputSha256: scenario.outputSha256,
        oracleAssertions: scenario.oracleAssertions,
      })),
    ),
  );
}

function assertExactGoldens(document) {
  assertObject(document, '$');
  assertEqual(document.$schema, 'schemas/exact-goldens.schema.json', '$.$schema');
  assertEqual(document.schemaVersion, 1, '$.schemaVersion');
  assertEqual(document.fixtureSetId, FIXTURE_SET_ID, '$.fixtureSetId');
  assertObject(document.capture, '$.capture');
  assertEqual(
    document.capture.sourceArchiveSha256,
    SOURCE_ARCHIVE_SHA256,
    '$.capture.sourceArchiveSha256',
  );
  assertEqual(document.capture.networkPolicy, 'loopbackOnly', '$.capture.networkPolicy');
  assertArray(document.scenarios, '$.scenarios');
  assertEqual(document.scenarioCount, document.scenarios.length, '$.scenarioCount');

  const ids = document.scenarios.map((scenario) => scenario.id);
  assertDeepEqual(ids, EXPECTED_SCENARIO_IDS, '$.scenarios[*].id');
  assertEqual(new Set(ids).size, ids.length, '$.scenarios[*].id uniqueness');

  const covered = new Set();
  for (let index = 0; index < document.scenarios.length; index += 1) {
    const scenario = document.scenarios[index];
    const path = `$.scenarios[${index}]`;
    assertObject(scenario, path);
    assertNonEmptyString(scenario.id, `${path}.id`);
    assertArray(scenario.coverage, `${path}.coverage`);
    if (scenario.coverage.length === 0) {
      fail(`${path}.coverage must not be empty`);
    }
    for (const item of scenario.coverage) {
      assertNonEmptyString(item, `${path}.coverage[]`);
      covered.add(item);
    }
    assertObject(scenario.input, `${path}.input`);
    assertObject(scenario.selectedState, `${path}.selectedState`);
    assertObject(scenario.output, `${path}.output`);
    assertArray(scenario.output.weeks, `${path}.output.weeks`);
    assertEqual(
      scenario.output.weekCount,
      scenario.output.weeks.length,
      `${path}.output.weekCount`,
    );
    if (scenario.output.weeks.length === 0) {
      fail(`${path}.output.weeks must not be empty`);
    }
    validateWeeks(scenario.output.weeks, `${path}.output.weeks`);
    assertEqual(
      scenario.outputSha256,
      outputSha256(scenario.output),
      `${path}.outputSha256`,
    );
    switch (scenario.id) {
      case 'gvt-10x10-alternate-4-day':
        validateGvtAlternateSameRatio(scenario, path);
        break;
      case 'bbb-challenge-six-weeks-same-lift':
        validateBbbChallengeSameLift(scenario, path);
        break;
      case 'bbb-challenge-thirteen-weeks-kg':
        validateKgChallengeTrainingMaxProgression(scenario, path);
        break;
      default:
        if (scenario.oracleAssertions !== undefined) {
          fail(`${path}.oracleAssertions is only valid for a scenario with explicit checks`);
        }
    }
  }

  for (const coverage of EXPECTED_COVERAGE) {
    if (!covered.has(coverage)) {
      fail(`missing required coverage: ${coverage}`);
    }
  }
  assertEqual(
    document.corpusSha256,
    corpusSha256(document.scenarios),
    '$.corpusSha256',
  );
}

function validateGvtAlternateSameRatio(scenario, path) {
  const proofPath = `${path}.oracleAssertions.gvtAlternateSameRatio`;
  assertObject(scenario.oracleAssertions, `${path}.oracleAssertions`);
  const proof = scenario.oracleAssertions.gvtAlternateSameRatio;
  assertObject(proof, proofPath);
  assertEqual(proof.alternateExercise, true, `${proofPath}.alternateExercise`);
  assertEqual(proof.useSameRatio, true, `${proofPath}.useSameRatio`);
  assertEqual(proof.ratioPercent, 30, `${proofPath}.ratioPercent`);
  assertEqual(proof.daysPerWeek, 4, `${proofPath}.daysPerWeek`);
  assertDeepEqual(
    proof.supplementalMovementByMain,
    {
      'Overhead Press': 'Bench Press',
      Deadlift: 'Squat',
      'Bench Press': 'Overhead Press',
      Squat: 'Deadlift',
    },
    `${proofPath}.supplementalMovementByMain`,
  );

  const template = scenario.selectedState.template;
  assertObject(template, `${path}.selectedState.template`);
  assertEqual(
    template.selects[1].selectedLabel,
    '30%',
    `${path}.selectedState.template.selects[1].selectedLabel`,
  );
  assertEqual(
    template.checkboxes[0].label,
    'Alternate exercise',
    `${path}.selectedState.template.checkboxes[0].label`,
  );
  assertEqual(
    template.checkboxes[0].checked,
    true,
    `${path}.selectedState.template.checkboxes[0].checked`,
  );
  assertEqual(
    template.checkboxes[1].label,
    'Use same ratio',
    `${path}.selectedState.template.checkboxes[1].label`,
  );
  assertEqual(
    template.checkboxes[1].checked,
    true,
    `${path}.selectedState.template.checkboxes[1].checked`,
  );
  assertEqual(
    scenario.selectedState.scheduling.daysPerWeek,
    proof.daysPerWeek,
    `${path}.selectedState.scheduling.daysPerWeek`,
  );

  const firstWeek = scenario.output.weeks[0];
  assertEqual(firstWeek.sessions.length, 4, `${path}.output.weeks[0].sessions.length`);
  for (const session of firstWeek.sessions) {
    const mainMovement = session.exercises[0]?.name;
    const supplementalMovement = proof.supplementalMovementByMain[mainMovement];
    assertNonEmptyString(
      supplementalMovement,
      `${proofPath}.supplementalMovementByMain.${mainMovement}`,
    );
    assertEqual(
      session.exercises[1]?.name,
      supplementalMovement,
      `${path}.output Week 1 ${mainMovement} alternate exercise`,
    );
    assertEqual(
      session.exercises[1]?.sets.length,
      10,
      `${path}.output Week 1 ${mainMovement} alternate set count`,
    );
  }
}

function validateBbbChallengeSameLift(scenario, path) {
  const proofPath = `${path}.oracleAssertions.bbbChallengeSameLift`;
  assertObject(scenario.oracleAssertions, `${path}.oracleAssertions`);
  const proof = scenario.oracleAssertions.bbbChallengeSameLift;
  assertObject(proof, proofPath);
  assertEqual(proof.duration, 'Six Weeks', `${proofPath}.duration`);
  assertEqual(proof.lessBoring, false, `${proofPath}.lessBoring`);
  assertEqual(
    proof.supplementalExerciseMode,
    'sameLift',
    `${proofPath}.supplementalExerciseMode`,
  );
  assertEqual(proof.daysPerWeek, 4, `${proofPath}.daysPerWeek`);

  const template = scenario.selectedState.template;
  assertObject(template, `${path}.selectedState.template`);
  assertEqual(
    template.selects[1].selectedLabel,
    proof.duration,
    `${path}.selectedState.template.selects[1].selectedLabel`,
  );
  assertEqual(
    template.checkboxes[0].label,
    'Less boring',
    `${path}.selectedState.template.checkboxes[0].label`,
  );
  assertEqual(
    template.checkboxes[0].checked,
    proof.lessBoring,
    `${path}.selectedState.template.checkboxes[0].checked`,
  );
  assertEqual(
    scenario.selectedState.scheduling.daysPerWeek,
    proof.daysPerWeek,
    `${path}.selectedState.scheduling.daysPerWeek`,
  );

  const firstWeek = scenario.output.weeks[0];
  assertEqual(firstWeek.sessions.length, 4, `${path}.output.weeks[0].sessions.length`);
  for (const session of firstWeek.sessions) {
    const mainExercise = session.exercises[0];
    assertObject(mainExercise, `${path}.output Week 1 main exercise`);
    assertEqual(
      mainExercise.sets.length,
      11,
      `${path}.output Week 1 ${mainExercise.name} combined main and supplemental sets`,
    );
    const pairedMajorMovements = session.exercises
      .slice(1)
      .filter((exercise) =>
        ['Overhead Press', 'Deadlift', 'Bench Press', 'Squat'].includes(exercise.name),
      );
    assertEqual(
      pairedMajorMovements.length,
      0,
      `${path}.output Week 1 ${mainExercise.name} paired major movements`,
    );
  }
}

function validateKgChallengeTrainingMaxProgression(scenario, path) {
  const proofPath = `${path}.oracleAssertions.bbbChallengeTrainingMaxProgression`;
  assertObject(scenario.oracleAssertions, `${path}.oracleAssertions`);
  const proof = scenario.oracleAssertions.bbbChallengeTrainingMaxProgression;
  assertObject(proof, proofPath);
  assertEqual(proof.unit, 'kg', `${proofPath}.unit`);
  assertEqual(proof.upperBodyIncrementKg, 2.5, `${proofPath}.upperBodyIncrementKg`);
  assertEqual(proof.lowerBodyIncrementKg, 5, `${proofPath}.lowerBodyIncrementKg`);
  assertDeepEqual(
    proof.cycleStartWeeks,
    [1, 4, 8, 11],
    `${proofPath}.cycleStartWeeks`,
  );
  assertEqual(
    scenario.selectedState.weight.unit,
    proof.unit,
    `${path}.selectedState.weight.unit`,
  );
  assertEqual(
    scenario.selectedState.weight.trainingMaxRatioPercent,
    90,
    `${path}.selectedState.weight.trainingMaxRatioPercent`,
  );
  assertEqual(
    scenario.input.weightInputOverride.unit,
    'kg',
    `${path}.input.weightInputOverride.unit`,
  );

  const movementIncrements = {
    'Overhead Press': proof.upperBodyIncrementKg,
    'Bench Press': proof.upperBodyIncrementKg,
    Squat: proof.lowerBodyIncrementKg,
    Deadlift: proof.lowerBodyIncrementKg,
  };
  assertObject(proof.trainingMaxByCycleKg, `${proofPath}.trainingMaxByCycleKg`);
  assertDeepEqual(
    Object.keys(proof.trainingMaxByCycleKg),
    Object.keys(movementIncrements),
    `${proofPath}.trainingMaxByCycleKg movements`,
  );
  for (const [movement, increment] of Object.entries(movementIncrements)) {
    const lift = scenario.selectedState.weight.lifts[movement];
    assertObject(lift, `${path}.selectedState.weight.lifts.${movement}`);
    const initialTrainingMax =
      (lift.weight * scenario.selectedState.weight.trainingMaxRatioPercent) / 100;
    const expectedProgression = proof.cycleStartWeeks.map(
      (_, cycleIndex) => initialTrainingMax + increment * cycleIndex,
    );
    const assertedProgression = proof.trainingMaxByCycleKg[movement];
    assertDeepEqual(
      assertedProgression,
      expectedProgression,
      `${proofPath}.trainingMaxByCycleKg.${movement}`,
    );

    for (let cycleIndex = 0; cycleIndex < proof.cycleStartWeeks.length; cycleIndex += 1) {
      const weekNumber = proof.cycleStartWeeks[cycleIndex];
      const week = scenario.output.weeks[weekNumber - 1];
      assertEqual(week.label, `Week ${weekNumber}`, `${path}.output.weeks cycle start`);
      const exercise = week.sessions
        .flatMap((session) => session.exercises)
        .find(
          (candidate) =>
            candidate.name === movement && candidate.sets.length >= 6,
        );
      assertObject(
        exercise,
        `${path}.output.weeks[${weekNumber - 1}].exercise.${movement}`,
      );
      const observedMainWork = exercise.sets.slice(-3).map((set) => set.work);
      const trainingMax = assertedProgression[cycleIndex];
      const expectedMainWork = [65, 75, 85].map((percentage, setIndex) => {
        const load = ceilToLoadStep((trainingMax * percentage) / 100, 2.5);
        return `${setIndex === 2 ? '5+' : '5'} x ${String(load)}`;
      });
      assertDeepEqual(
        observedMainWork,
        expectedMainWork,
        `${path}.output Week ${weekNumber} ${movement} main work`,
      );
    }
  }
}

function ceilToLoadStep(value, step) {
  return Math.ceil(value / step - 1e-10) * step;
}

function validateWeeks(weeks, path) {
  for (let weekIndex = 0; weekIndex < weeks.length; weekIndex += 1) {
    const week = weeks[weekIndex];
    const weekPath = `${path}[${weekIndex}]`;
    assertObject(week, weekPath);
    assertNonEmptyString(week.label, `${weekPath}.label`);
    assertArray(week.sessions, `${weekPath}.sessions`);
    if (week.sessions.length === 0) {
      fail(`${weekPath}.sessions must not be empty`);
    }
    for (let sessionIndex = 0; sessionIndex < week.sessions.length; sessionIndex += 1) {
      const session = week.sessions[sessionIndex];
      const sessionPath = `${weekPath}.sessions[${sessionIndex}]`;
      assertObject(session, sessionPath);
      assertEqual(session.position, sessionIndex + 1, `${sessionPath}.position`);
      assertArray(session.exercises, `${sessionPath}.exercises`);
      if (session.exercises.length === 0) {
        fail(`${sessionPath}.exercises must not be empty`);
      }
      for (
        let exerciseIndex = 0;
        exerciseIndex < session.exercises.length;
        exerciseIndex += 1
      ) {
        const exercise = session.exercises[exerciseIndex];
        const exercisePath = `${sessionPath}.exercises[${exerciseIndex}]`;
        assertObject(exercise, exercisePath);
        assertNonEmptyString(exercise.name, `${exercisePath}.name`);
        assertArray(exercise.sets, `${exercisePath}.sets`);
        if (exercise.sets.length === 0) {
          fail(`${exercisePath}.sets must not be empty`);
        }
        for (let setIndex = 0; setIndex < exercise.sets.length; setIndex += 1) {
          const set = exercise.sets[setIndex];
          const setPath = `${exercisePath}.sets[${setIndex}]`;
          assertObject(set, setPath);
          assertNonEmptyString(set.work, `${setPath}.work`);
          assertArray(set.plates, `${setPath}.plates`);
          for (const plate of set.plates) {
            assertNonEmptyString(plate, `${setPath}.plates[]`);
          }
        }
      }
    }
  }
}

function assertObject(value, path) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${path} must be an object`);
  }
}

function assertArray(value, path) {
  if (!Array.isArray(value)) {
    fail(`${path} must be an array`);
  }
}

function assertNonEmptyString(value, path) {
  if (typeof value !== 'string' || value.length === 0) {
    fail(`${path} must be a non-empty string`);
  }
}

function assertEqual(actual, expected, path) {
  if (actual !== expected) {
    fail(`${path}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertDeepEqual(actual, expected, path) {
  if (stableStringify(actual) !== stableStringify(expected)) {
    fail(`${path}: expected ${stableStringify(expected)}, got ${stableStringify(actual)}`);
  }
}

function fail(message) {
  throw new Error(`Exact golden integrity failure: ${message}`);
}

module.exports = {
  EXPECTED_COVERAGE,
  EXPECTED_SCENARIO_IDS,
  FIXTURE_SET_ID,
  SOURCE_ARCHIVE_SHA256,
  assertExactGoldens,
  corpusSha256,
  outputSha256,
  sha256,
  stableStringify,
};
