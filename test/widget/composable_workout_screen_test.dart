import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/workout_runtime/domain/composable_workout.dart';
import 'package:hybrid_training/features/workout_runtime/presentation/composable_workout_screen.dart';

void main() {
  testWidgets('separates only blueprint blocks at 390 x 844', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workout = ComposableWorkout(
      id: 's',
      blocks: [
        WorkoutBlock(
          id: 'main',
          sequence: 0,
          role: WorkoutBlockRole.mainWork,
          movementId: 'squat',
          prescriptions: const [
            WorkoutPrescription(
              id: 'p',
              label: '5/3/1',
              target: ActivityTarget(
                type: TargetType.setsRepsLoad,
                sets: 3,
                reps: 5,
                load: 100,
              ),
            ),
          ],
        ),
        WorkoutBlock(
          id: 'easy',
          sequence: 1,
          role: WorkoutBlockRole.conditioningEasy,
          prescriptions: const [
            WorkoutPrescription(
              id: 'c',
              label: 'Marche',
              target: ActivityTarget(
                type: TargetType.duration,
                durationSeconds: 1200,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ComposableWorkoutScreen(
          workout: workout,
          onPrevious: null,
          onNext: () {},
          onRecord: (_, _) {},
        ),
      ),
    );
    expect(find.byKey(const Key('block-mainWork')), findsOneWidget);
    expect(find.byKey(const Key('block-conditioningEasy')), findsOneWidget);
    expect(find.byKey(const Key('block-mobility')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
