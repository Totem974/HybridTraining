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
            tooltip: strings.notifications,
            onPressed: () =>
                _openPanel(context, _SimplePanel(title: strings.notifications)),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        key: const Key('home-dashboard'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(_date(context, DateTime.now()), textAlign: TextAlign.center),
          const SizedBox(height: 18),
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
      bottomNavigationBar: _AppBottomBar(
        selectedIndex: 0,
        onSelected: (index) {
          if (index == 2 && snapshot.nextSession != null) {
            _openWorkout(context, snapshot.nextSession!);
          } else if (index == 1) {
            _openPanel(context, _StatsPanel(snapshot: snapshot));
          } else if (index == 3) {
            _openPanel(context, _ProfilePanel(snapshot: snapshot));
          } else if (index == 4) {
            _openPanel(context, const _SettingsPanel());
          }
        },
      ),
    );
  }

  Future<void> _openPanel(BuildContext context, Widget panel) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => panel));

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
      color: Theme.of(context).colorScheme.primary,
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
                backgroundColor: Color(0x26000000),
                foregroundColor: Color(0xFF1A0E00),
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

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(top: BorderSide(color: Color(0x18FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(context, 0, Icons.home_rounded),
          _item(context, 1, Icons.bar_chart_rounded),
          IconButton.filled(
            key: const Key('quick-workout'),
            onPressed: () => onSelected(2),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF5821F),
              foregroundColor: const Color(0xFF1A0E00),
              minimumSize: const Size(46, 46),
            ),
            icon: const Icon(Icons.add),
          ),
          _item(context, 3, Icons.person_rounded),
          _item(context, 4, Icons.settings_rounded),
        ],
      ),
    ),
  );

  Widget _item(BuildContext context, int index, IconData icon) => IconButton(
    key: Key('nav-$index'),
    onPressed: () => onSelected(index),
    color: selectedIndex == index
        ? const Color(0xFFF2F1EE)
        : const Color(0x73F2F1EE),
    icon: Icon(icon),
  );
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.snapshot});

  final TrainingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(title: Text(strings.statistics)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '${snapshot.history.length}',
                  label: strings.sessions,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  value: snapshot.nextSession == null ? '✓' : '1',
                  label: strings.cycleWeek,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(strings.recordsComingFromWorkouts),
        ],
      ),
      bottomNavigationBar: _AppBottomBar(
        selectedIndex: 1,
        onSelected: (index) => _panelNavigation(context, index),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          Text(label),
        ],
      ),
    ),
  );
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.snapshot});

  final TrainingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final initials = snapshot.displayName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFF5821F),
                foregroundColor: const Color(0xFF1A0E00),
                child: Text(initials),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(strings.foundationProgram),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PanelTile(
            icon: Icons.history,
            label: strings.history,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => _HistoryPanel(history: snapshot.history),
              ),
            ),
          ),
          _PanelTile(
            icon: Icons.bar_chart,
            label: strings.statistics,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => _StatsPanel(snapshot: snapshot),
              ),
            ),
          ),
          _PanelTile(icon: Icons.tune, label: strings.editLoads),
          _PanelTile(icon: Icons.settings, label: strings.settings),
        ],
      ),
      bottomNavigationBar: _AppBottomBar(
        selectedIndex: 3,
        onSelected: (index) => _panelNavigation(context, index),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.preferences, style: _sectionStyle),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(strings.units),
                  trailing: const Text('kg'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(strings.notifications),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.program, style: _sectionStyle),
          const SizedBox(height: 8),
          _PanelTile(
            icon: Icons.menu_book,
            label: strings.manageProgram,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _ProgramLibraryPanel()),
            ),
          ),
          _PanelTile(icon: Icons.tune, label: strings.editCycle),
        ],
      ),
      bottomNavigationBar: _AppBottomBar(
        selectedIndex: 4,
        onSelected: (index) => _panelNavigation(context, index),
      ),
    );
  }
}

class _SimplePanel extends StatelessWidget {
  const _SimplePanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const SizedBox.shrink(),
  );
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.history});

  final List<StoredSession> history;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(title: Text(strings.history)),
      body: history.isEmpty
          ? Center(child: Text(strings.noHistory))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final session = history[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0x26F5821F),
                      foregroundColor: const Color(0xFFF5821F),
                      child: Text(_liftCode(session.lift)),
                    ),
                    title: Text(strings.lift(session.lift.name)),
                    subtitle: Text(_date(context, session.scheduledFor)),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF3ECB6A),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProgramLibraryPanel extends StatefulWidget {
  const _ProgramLibraryPanel();

  @override
  State<_ProgramLibraryPanel> createState() => _ProgramLibraryPanelState();
}

class _ProgramLibraryPanelState extends State<_ProgramLibraryPanel> {
  int _generation = 0;

  static const _programs = [
    _ProgramPreview(
      name: 'Original 5/3/1 + First Set Last',
      generation: 0,
      page: 'Forever · PDF 180–181',
      ready: true,
    ),
    _ProgramPreview(
      name: 'Boring But Big',
      generation: 0,
      page: 'Forever · PDF 57',
    ),
    _ProgramPreview(
      name: 'Full Body (1000% Awesome)',
      generation: 0,
      page: 'Forever · PDF 86',
    ),
    _ProgramPreview(
      name: '5/3/1 Beyond',
      generation: 1,
      page: 'Catalogue indexé',
    ),
    _ProgramPreview(
      name: '5/3/1 Classic',
      generation: 2,
      page: 'Catalogue indexé',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final visible = _programs.where((item) => item.generation == _generation);
    return Scaffold(
      appBar: AppBar(title: Text(strings.library)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.libraryDescription),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Forever')),
              ButtonSegment(value: 1, label: Text('Beyond')),
              ButtonSegment(value: 2, label: Text('Classic')),
            ],
            selected: {_generation},
            onSelectionChanged: (value) =>
                setState(() => _generation = value.single),
          ),
          const SizedBox(height: 16),
          for (final program in visible)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  program.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(program.page),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _ProgramDetailPanel(program: program),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgramDetailPanel extends StatelessWidget {
  const _ProgramDetailPanel({required this.program});

  final _ProgramPreview program;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(title: Text(strings.programDetails)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              program.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(program.page),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  program.ready
                      ? strings.programRulesValidated
                      : strings.programRulesNeedReview,
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: null,
              child: Text(
                program.ready ? strings.currentProgram : strings.comingSoon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramPreview {
  const _ProgramPreview({
    required this.name,
    required this.generation,
    required this.page,
    this.ready = false,
  });

  final String name;
  final int generation;
  final String page;
  final bool ready;
}

class _PanelTile extends StatelessWidget {
  const _PanelTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFFF5821F)),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

const _sectionStyle = TextStyle(
  color: Color(0xFFF5821F),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

void _panelNavigation(BuildContext context, int index) {
  if (index == 0) Navigator.of(context).popUntil((route) => route.isFirst);
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
                color: Theme.of(context).colorScheme.surface,
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
String _liftCode(MainLift lift) => switch (lift) {
  MainLift.squat => 'SQ',
  MainLift.benchPress => 'BP',
  MainLift.deadlift => 'DL',
  MainLift.overheadPress => 'OP',
};
