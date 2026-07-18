import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/workout_runtime/domain/composable_workout.dart';

class ComposableWorkoutScreen extends StatelessWidget {
  const ComposableWorkoutScreen({
    super.key,
    required this.workout,
    required this.onPrevious,
    required this.onNext,
    required this.onRecord,
    this.strings = const AppStrings(),
  });
  final ComposableWorkout workout;
  final VoidCallback? onPrevious, onNext;
  final void Function(String, PrescriptionStatus) onRecord;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final active = workout.activeBlock!;
    return Scaffold(
      appBar: AppBar(title: Text(strings.workout)),
      body: SafeArea(
        child: ListView(
          key: const Key('composable-workout'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${workout.activeBlockIndex + 1} / ${workout.blocks.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            for (final block in workout.blocks)
              Card(
                key: Key('block-${block.role.name}'),
                color: block.id == active.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.workoutBlockRole(block.role.name),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (block.movementId != null) Text(block.movementId!),
                      const SizedBox(height: 8),
                      for (final item in block.prescriptions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.label),
                          subtitle: Text(_target(item.target)),
                          trailing: PopupMenuButton<PrescriptionStatus>(
                            onSelected: (value) => onRecord(item.id, value),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: PrescriptionStatus.success,
                                child: Text(strings.successfulResult),
                              ),
                              PopupMenuItem(
                                value: PrescriptionStatus.failure,
                                child: Text(strings.failedResult),
                              ),
                              PopupMenuItem(
                                value: PrescriptionStatus.skipped,
                                child: Text(strings.skippedResult),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrevious,
                    child: Text(strings.previousBlock),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onNext,
                    child: Text(strings.nextBlock),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _target(ActivityTarget target) => switch (target.type) {
  TargetType.setsRepsLoad => '${target.sets} × ${target.reps} · ${target.load}',
  TargetType.totalReps => '${target.totalReps} répétitions',
  TargetType.duration => '${target.durationSeconds} s',
  TargetType.distance => '${target.distanceMeters} m',
  TargetType.rounds => '${target.rounds} tours',
  TargetType.completion => 'À réaliser',
};
