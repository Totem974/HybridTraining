import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

class TrainingHomeScreen extends StatelessWidget {
  const TrainingHomeScreen({
    required this.snapshot,
    required this.onCompleteSet,
    required this.onFinishSession,
    super.key,
  });

  final TrainingSnapshot snapshot;
  final Future<void> Function(String id, int repetitions) onCompleteSet;
  final Future<void> Function(String id) onFinishSession;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Hybrid 5/3/1 — ${snapshot.displayName}'),
          bottom: TabBar(
            tabs: [
              Tab(text: strings.workout),
              Tab(text: strings.history),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _WorkoutTab(
              session: snapshot.nextSession,
              onCompleteSet: onCompleteSet,
              onFinishSession: onFinishSession,
            ),
            _HistoryTab(history: snapshot.history),
          ],
        ),
      ),
    );
  }
}

class _WorkoutTab extends StatelessWidget {
  const _WorkoutTab({
    required this.session,
    required this.onCompleteSet,
    required this.onFinishSession,
  });

  final StoredSession? session;
  final Future<void> Function(String id, int repetitions) onCompleteSet;
  final Future<void> Function(String id) onFinishSession;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final current = session;
    if (current == null) return Center(child: Text(strings.noSession));
    final unit = current.unit == WeightUnit.kilograms ? 'kg' : 'lb';
    final allDone = current.sets.every((set) => set.isComplete);
    return ListView(
      key: const Key('workout-session'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.lift(current.lift.name),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(current.scheduledFor.toIso8601String().substring(0, 10)),
        const SizedBox(height: 16),
        for (final set in current.sets)
          Card(
            child: ListTile(
              leading: Icon(
                set.isComplete
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              title: Text(
                '${set.load.toStringAsFixed(set.load % 1 == 0 ? 0 : 1)} $unit × ${set.repetitions}${set.isPerformanceSet ? '+' : ''}',
              ),
              subtitle: Text(
                set.kind == SetKind.main
                    ? 'Travail principal'
                    : 'First Set Last',
              ),
              trailing: set.isComplete
                  ? null
                  : TextButton(
                      key: Key('complete-${set.id}'),
                      onPressed: () => onCompleteSet(set.id, set.repetitions),
                      child: Text(strings.done),
                    ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('finish-session'),
          onPressed: allDone ? () => onFinishSession(current.id) : null,
          child: Text(strings.finishSession),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});

  final List<StoredSession> history;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    if (history.isEmpty) return Center(child: Text(strings.noHistory));
    return ListView(
      key: const Key('history-list'),
      children: [
        for (final session in history)
          ListTile(
            leading: const Icon(Icons.check_circle),
            title: Text(strings.lift(session.lift.name)),
            subtitle: Text(
              session.scheduledFor.toIso8601String().substring(0, 10),
            ),
          ),
      ],
    );
  }
}
