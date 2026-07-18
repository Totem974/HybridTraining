import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/workout_runtime/domain/composable_workout.dart';

void main() {
  test('keeps blueprint order and supports multiple movements and targets', () {
    final workout = ComposableWorkout(
      id: 'session',
      blocks: [
        _block(
          'warm',
          0,
          WorkoutBlockRole.warmUp,
          const ActivityTarget(type: TargetType.duration, durationSeconds: 300),
        ),
        _block(
          'squat',
          1,
          WorkoutBlockRole.mainWork,
          const ActivityTarget(
            type: TargetType.setsRepsLoad,
            sets: 3,
            reps: 5,
            load: 100,
          ),
          movement: 'squat',
        ),
        _block(
          'bench',
          2,
          WorkoutBlockRole.mainWork,
          const ActivityTarget(type: TargetType.totalReps, totalReps: 25),
          movement: 'benchPress',
        ),
        _block(
          'run',
          3,
          WorkoutBlockRole.conditioningEasy,
          const ActivityTarget(type: TargetType.distance, distanceMeters: 2000),
        ),
      ],
    );
    expect(workout.blocks.map((block) => block.id), [
      'warm',
      'squat',
      'bench',
      'run',
    ]);
    expect(workout.moveNext(), 1);
    expect(workout.movePrevious(), 0);
  });

  test('rejects non contiguous blueprint order', () {
    expect(
      () => ComposableWorkout(
        id: 'bad',
        blocks: [
          _block(
            'a',
            1,
            WorkoutBlockRole.mobility,
            const ActivityTarget(type: TargetType.completion),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('summarizes success failure and skipped prescriptions', () {
    final workout = ComposableWorkout(
      id: 'summary',
      blocks: [
        WorkoutBlock(
          id: 'results',
          sequence: 0,
          role: WorkoutBlockRole.personalRecordTest,
          prescriptions: const [
            WorkoutPrescription(
              id: 'a',
              label: 'a',
              target: ActivityTarget(type: TargetType.completion),
              status: PrescriptionStatus.success,
            ),
            WorkoutPrescription(
              id: 'b',
              label: 'b',
              target: ActivityTarget(type: TargetType.rounds, rounds: 3),
              status: PrescriptionStatus.failure,
            ),
            WorkoutPrescription(
              id: 'c',
              label: 'c',
              target: ActivityTarget(type: TargetType.completion),
              status: PrescriptionStatus.skipped,
            ),
          ],
        ),
      ],
    );
    final summary = WorkoutSummary.fromWorkout(workout);
    expect(
      [summary.total, summary.success, summary.failure, summary.skipped],
      [3, 1, 1, 1],
    );
  });
}

WorkoutBlock _block(
  String id,
  int sequence,
  WorkoutBlockRole role,
  ActivityTarget target, {
  String? movement,
}) => WorkoutBlock(
  id: id,
  sequence: sequence,
  role: role,
  movementId: movement,
  prescriptions: [
    WorkoutPrescription(id: '$id-item', label: id, target: target),
  ],
);
