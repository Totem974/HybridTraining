import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/gyms/domain/plate_calculator.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

class TrainingHomeScreen extends StatelessWidget {
  const TrainingHomeScreen({
    required this.snapshot,
    required this.onCompleteSet,
    required this.onFinishSession,
    required this.onUpdateNotes,
    required this.onStartSession,
    required this.onRecordSet,
    required this.onSetRestUntil,
    super.key,
  });

  final TrainingSnapshot snapshot;
  final Future<void> Function(String id, int repetitions) onCompleteSet;
  final Future<void> Function(String id) onFinishSession;
  final Future<void> Function(String id, String notes) onUpdateNotes;
  final Future<void> Function(String id) onStartSession;
  final Future<void> Function(String id, int repetitions, SetResult result)
  onRecordSet;
  final Future<void> Function(String id, DateTime? restUntil) onSetRestUntil;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(
        title: const Text('HYBRID 5/3/1'),
        actions: [
          IconButton(
            tooltip: strings.settings,
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(strings.settingsComingSoon))),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView(
        key: const Key('home-dashboard'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${strings.hello} ${snapshot.displayName}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 28),
          Text(strings.thisWeek, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (snapshot.nextSession case final session?)
            _NextWorkoutCard(
              session: session,
              onOpen: () => _openWorkout(context, session),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(strings.noSession),
              ),
            ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.currentCycle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(onPressed: null, child: Text(strings.edit)),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.foundationProgram,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(strings.cycleDescription),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(strings.history, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (snapshot.history.isEmpty)
            Text(strings.noHistory)
          else
            for (final session in snapshot.history)
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(strings.lift(session.lift.name)),
                subtitle: Text(_date(context, session.scheduledFor)),
              ),
        ],
      ),
    );
  }

  Future<void> _openWorkout(BuildContext context, StoredSession session) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          session: session,
          onCompleteSet: onCompleteSet,
          onFinishSession: onFinishSession,
          onUpdateNotes: onUpdateNotes,
          onStartSession: onStartSession,
          onRecordSet: onRecordSet,
          onSetRestUntil: onSetRestUntil,
        ),
      ),
    );
  }
}

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({required this.session, required this.onOpen});

  final StoredSession session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final main = session.sets.where((set) => set.kind == SetKind.main).last;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        key: const Key('open-workout'),
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 34,
                child: Icon(Icons.fitness_center, size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_date(context, session.scheduledFor)),
                    Text(
                      strings.lift(session.lift.name),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${strings.topSet}: ${_load(main.load)} ${_unit(session.unit)} × ${main.repetitions}${main.isPerformanceSet ? '+' : ''}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({
    required this.session,
    required this.onCompleteSet,
    required this.onFinishSession,
    required this.onUpdateNotes,
    required this.onStartSession,
    required this.onRecordSet,
    required this.onSetRestUntil,
    super.key,
  });

  final StoredSession session;
  final Future<void> Function(String id, int repetitions) onCompleteSet;
  final Future<void> Function(String id) onFinishSession;
  final Future<void> Function(String id, String notes) onUpdateNotes;
  final Future<void> Function(String id) onStartSession;
  final Future<void> Function(String id, int repetitions, SetResult result)
  onRecordSet;
  final Future<void> Function(String id, DateTime? restUntil) onSetRestUntil;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final main = session.sets.where((set) => set.kind == SetKind.main);
    final supplemental = session.sets.where(
      (set) => set.kind == SetKind.supplemental,
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.workout)),
      body: ListView(
        key: const Key('workout-session'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.lift(session.lift.name),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(_date(context, session.scheduledFor)),
          const SizedBox(height: 24),
          _SetSection(title: strings.mainSets, sets: main, unit: session.unit),
          const SizedBox(height: 20),
          _SetSection(
            title: strings.firstSetLast,
            sets: supplemental,
            unit: session.unit,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('start-workout'),
            onPressed: () async {
              await onStartSession(session.id);
              if (!context.mounted) return;
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ActiveWorkoutScreen(
                    session: session,
                    onFinishSession: onFinishSession,
                    onUpdateNotes: onUpdateNotes,
                    onRecordSet: onRecordSet,
                    onSetRestUntil: onSetRestUntil,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(strings.startWorkout),
          ),
        ],
      ),
    );
  }
}

class _SetSection extends StatelessWidget {
  const _SetSection({
    required this.title,
    required this.sets,
    required this.unit,
  });

  final String title;
  final Iterable<StoredSet> sets;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            for (final set in sets)
              ListTile(
                leading: Icon(
                  set.isComplete
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(
                  '${_load(set.load)} ${_unit(unit)} × ${set.repetitions}${set.isPerformanceSet ? '+' : ''}',
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({
    required this.session,
    required this.onFinishSession,
    required this.onUpdateNotes,
    required this.onRecordSet,
    required this.onSetRestUntil,
    super.key,
  });

  final StoredSession session;
  final Future<void> Function(String id) onFinishSession;
  final Future<void> Function(String id, String notes) onUpdateNotes;
  final Future<void> Function(String id, int repetitions, SetResult result)
  onRecordSet;
  final Future<void> Function(String id, DateTime? restUntil) onSetRestUntil;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final List<bool> _completed = [
    for (final set in widget.session.sets) set.isComplete,
  ];
  late final List<SetResult?> _results = [
    for (final set in widget.session.sets) set.result,
  ];
  late final TextEditingController _notes = TextEditingController(
    text: widget.session.notes,
  );
  Timer? _timer;
  Timer? _notesDebounce;
  int _restSeconds = 0;
  bool _busy = false;
  int? _enteredRepetitions;

  int get _currentIndex => _completed.indexWhere((done) => !done);

  @override
  void initState() {
    super.initState();
    final restUntil = widget.session.restUntil;
    if (restUntil != null) {
      _restSeconds = restUntil.difference(DateTime.now().toUtc()).inSeconds;
      if (_restSeconds > 0) _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesDebounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final index = _currentIndex;
    final finished = index == -1;
    final current = finished ? null : widget.session.sets[index];
    _enteredRepetitions ??= current?.repetitions;
    return Scaffold(
      appBar: AppBar(title: Text(strings.activeWorkout)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              finished ? strings.workoutComplete : strings.next,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (current != null)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text(
                        current.kind == SetKind.main
                            ? strings.mainSets
                            : strings.firstSetLast,
                      ),
                      if (current.isPerformanceSet) ...[
                        const SizedBox(height: 20),
                        Text(strings.amrapRepetitions),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: (_enteredRepetitions ?? 0) > 0
                                  ? () => setState(
                                      () => _enteredRepetitions =
                                          _enteredRepetitions! - 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$_enteredRepetitions',
                              key: const Key('entered-repetitions'),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            IconButton(
                              onPressed: () => setState(
                                () => _enteredRepetitions =
                                    _enteredRepetitions! + 1,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PlateHint(load: current.load, unit: widget.session.unit),
                      const SizedBox(height: 10),
                      Text(
                        strings.lift(widget.session.lift.name),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${_load(current.load)} ${_unit(widget.session.unit)}  ×  ${current.repetitions}${current.isPerformanceSet ? '+' : ''}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
              ),
            if (_restSeconds > 0) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(strings.rest),
                      Text(
                        _duration(_restSeconds),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      TextButton(
                        onPressed: _skipRest,
                        child: Text(strings.skipRest),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              onChanged: _scheduleNotesSave,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: strings.sessionNotes,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 20),
            if (finished)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '${_results.where((result) => result == SetResult.success).length} ${strings.successfulSets} · '
                    '${_results.where((result) => result == SetResult.failure).length} ${strings.failedSets} · '
                    '${_results.where((result) => result == SetResult.skipped).length} ${strings.skippedSets}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (finished)
              FilledButton(
                key: const Key('finish-session'),
                onPressed: _busy ? null : _finish,
                child: Text(strings.finishSession),
              )
            else ...[
              FilledButton(
                key: const Key('complete-current-set'),
                onPressed: _busy ? null : () => _record(SetResult.success),
                child: Text(strings.setComplete),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('fail-current-set'),
                      onPressed: _busy
                          ? null
                          : () => _record(SetResult.failure),
                      child: Text(strings.setFailed),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      key: const Key('skip-current-set'),
                      onPressed: _busy
                          ? null
                          : () => _record(SetResult.skipped),
                      child: Text(strings.skipSet),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${_completed.where((done) => done).length}/${_completed.length} ${strings.setsCompleted}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(SetResult result) async {
    final index = _currentIndex;
    if (index < 0) return;
    setState(() => _busy = true);
    final set = widget.session.sets[index];
    final repetitions = result == SetResult.skipped
        ? 0
        : _enteredRepetitions ?? set.repetitions;
    await widget.onRecordSet(set.id, repetitions, result);
    if (!mounted) return;
    setState(() {
      _completed[index] = true;
      _results[index] = result;
      _busy = false;
      _enteredRepetitions = _currentIndex == -1
          ? null
          : widget.session.sets[_currentIndex].repetitions;
      if (_currentIndex != -1) _restSeconds = 180;
    });
    if (_currentIndex != -1) {
      final restUntil = DateTime.now().toUtc().add(
        const Duration(seconds: 180),
      );
      await widget.onSetRestUntil(widget.session.id, restUntil);
      _startTimer();
    }
  }

  Future<void> _skipRest() async {
    setState(() => _restSeconds = 0);
    await widget.onSetRestUntil(widget.session.id, null);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _restSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    _notesDebounce?.cancel();
    await widget.onUpdateNotes(widget.session.id, _notes.text);
    await widget.onFinishSession(widget.session.id);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _scheduleNotesSave(String notes) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 600), () {
      widget.onUpdateNotes(widget.session.id, notes);
    });
  }
}

class _PlateHint extends StatelessWidget {
  const _PlateHint({required this.load, required this.unit});

  final double load;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final kilograms = unit == WeightUnit.kilograms;
    final result = const PlateCalculator().exact(
      target: load,
      barWeight: kilograms ? 20 : 45,
      inventory: kilograms
          ? const [
              PlateInventoryItem(weight: 20, quantity: 10),
              PlateInventoryItem(weight: 10, quantity: 10),
              PlateInventoryItem(weight: 5, quantity: 10),
              PlateInventoryItem(weight: 2.5, quantity: 10),
              PlateInventoryItem(weight: 1.25, quantity: 10),
            ]
          : const [
              PlateInventoryItem(weight: 45, quantity: 10),
              PlateInventoryItem(weight: 25, quantity: 10),
              PlateInventoryItem(weight: 10, quantity: 10),
              PlateInventoryItem(weight: 5, quantity: 10),
              PlateInventoryItem(weight: 2.5, quantity: 10),
            ],
    );
    if (result == null) return Text(strings.noExactPlateLoad);
    final plates = result.perSide.isEmpty
        ? strings.emptyBar
        : result.perSide.map(_load).join(' + ');
    return Text('${strings.perSide}: $plates ${_unit(unit)}');
  }
}

String _load(double value) => value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
String _unit(WeightUnit unit) => unit == WeightUnit.kilograms ? 'kg' : 'lb';
String _date(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatMediumDate(date);
String _duration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
