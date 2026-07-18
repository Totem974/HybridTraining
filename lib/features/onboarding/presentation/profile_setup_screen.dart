import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/programs/presentation/program_library_screen.dart';
import 'package:hybrid_training/features/programs/domain/training_schedule.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({required this.onSubmit, super.key});

  final Future<void> Function(FoundationProfileInput input) onSubmit;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _maxes = {
    for (final lift in MainLift.values) lift: TextEditingController(),
  };
  WeightUnit _unit = WeightUnit.kilograms;
  int _step = 0;
  int _daysPerWeek = 4;
  DateTime _startDate = DateTime.now();
  List<TrainingWeekday> _selectedWeekdays = const [
    TrainingWeekday.monday,
    TrainingWeekday.tuesday,
    TrainingWeekday.thursday,
    TrainingWeekday.saturday,
  ];
  List<MainLift> _liftOrder = const [
    MainLift.deadlift,
    MainLift.squat,
    MainLift.benchPress,
    MainLift.overheadPress,
  ];
  bool _saving = false;
  String? _saveError;
  String _selectedPresetId = 'forever-original-fsl-v1';

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _maxes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.onboardingTitles[_step],
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Text('${_step + 1}/6'),
                ],
              ),
            ),
            LinearProgressIndicator(value: (_step + 1) / 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _introStep(strings),
                    1 => _programStep(strings),
                    2 => _scheduleStep(strings),
                    3 => _maxStep(strings),
                    4 => _validationStep(strings),
                    _ => _readyStep(strings),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_saveError != null) ...[
                    Text(
                      _saveError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _step--),
                            child: Text(strings.back),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: Key(_step == 5 ? 'create-cycle' : 'continue'),
                          onPressed:
                              _saving ||
                                  (_step == 2 &&
                                      _scheduleDefinition.validate().isNotEmpty)
                              ? null
                              : _continue,
                          child: Text(
                            _saving
                                ? strings.creating
                                : _step == 5
                                ? strings.createCycle
                                : strings.continueLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introStep(AppStrings strings) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HYBRID',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFF5821F),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '5/3/1',
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 28),
        Text(
          strings.introMessage,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );

  Widget _maxStep(AppStrings strings) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(strings.maxInstructions),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('profile-name'),
          controller: _name,
          decoration: InputDecoration(labelText: strings.displayName),
          validator: (value) => value == null || value.trim().isEmpty
              ? strings.requiredField
              : null,
        ),
        const SizedBox(height: 16),
        SegmentedButton<WeightUnit>(
          segments: const [
            ButtonSegment(value: WeightUnit.kilograms, label: Text('kg')),
            ButtonSegment(value: WeightUnit.pounds, label: Text('lb')),
          ],
          selected: {_unit},
          onSelectionChanged: (value) => setState(() => _unit = value.single),
        ),
        const SizedBox(height: 20),
        for (final lift in MainLift.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: Key('max-${lift.name}'),
              controller: _maxes[lift],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: strings.lift(lift.name),
                suffixText: _unit == WeightUnit.kilograms ? 'kg' : 'lb',
              ),
              validator: (value) {
                final parsed = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return parsed == null || parsed <= 0
                    ? strings.positiveValueRequired
                    : null;
              },
            ),
          ),
      ],
    ),
  );

  Widget _programStep(AppStrings strings) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        strings.programPrompt,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          key: const Key('recommended-program'),
          contentPadding: const EdgeInsets.all(18),
          leading: const Icon(Icons.fitness_center),
          title: const Text('5/3/1 Forever'),
          subtitle: Text(
            'Original 5/3/1 + First Set Last 5 × 5\n${strings.currentVerifiedAvailable}\n${strings.fourDaysRecommended}',
          ),
          trailing: _selectedPresetId == 'forever-original-fsl-v1'
              ? const Icon(Icons.check_circle)
              : null,
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        key: const Key('view-current-programs'),
        onPressed: () => _openLibrary(),
        child: Text(strings.viewCurrentPrograms),
      ),
      for (final generation in MethodGeneration.values)
        TextButton(
          key: Key('explore-${generation.name}'),
          onPressed: () => _openLibrary(origin: generation),
          child: Text(
            strings.exploreOrigin(strings.generationLabel(generation.name)),
          ),
        ),
      TextButton(
        key: const Key('browse-program-library'),
        onPressed: () => _openLibrary(showAll: true),
        child: Text(strings.browseLibrary),
      ),
    ],
  );

  Widget _scheduleStep(AppStrings strings) {
    final preview = _schedulePreview;
    return ListView(
      key: const Key('planning-step'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          strings.startPrompt,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            key: const Key('pick-start-date'),
            leading: const Icon(Icons.calendar_today),
            title: Text(
              MaterialLocalizations.of(context).formatMediumDate(_startDate),
            ),
            subtitle: Text(strings.startDate),
            onTap: _pickDate,
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              key: const Key('date-today'),
              onPressed: () => _setStartDate(DateTime.now()),
              child: Text(strings.today),
            ),
            TextButton(
              key: const Key('date-tomorrow'),
              onPressed: () =>
                  _setStartDate(DateTime.now().add(const Duration(days: 1))),
              child: Text(strings.tomorrow),
            ),
            TextButton(
              key: const Key('date-next-monday'),
              onPressed: _nextMonday,
              child: Text(strings.nextMonday),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          strings.frequencyPrompt,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 3, label: Text(strings.threeDays)),
            ButtonSegment(value: 4, label: Text(strings.fourDays)),
          ],
          selected: {_daysPerWeek},
          onSelectionChanged: (value) => _changeFrequency(value.single),
        ),
        const SizedBox(height: 20),
        Text(
          strings.trainingDays,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          strings.daysSelected(_selectedWeekdays.length, _daysPerWeek),
          key: const Key('selected-day-count'),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final day in TrainingWeekday.values)
              Semantics(
                selected: _selectedWeekdays.contains(day),
                label: strings.weekdayLong(day.isoValue),
                child: FilterChip(
                  key: Key('weekday-${day.isoValue}'),
                  label: Text(strings.weekdayShort(day.isoValue)),
                  selected: _selectedWeekdays.contains(day),
                  onSelected: (_) => _toggleWeekday(day),
                ),
              ),
          ],
        ),
        if (_hasConsecutiveWarning)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              strings.consecutiveDaysWarning,
              key: const Key('consecutive-warning'),
              style: const TextStyle(color: Colors.amber),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          _daysPerWeek == 4
              ? strings.fixedAssignments
              : strings.rotationAcrossDays,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          itemCount: _liftOrder.length,
          onReorderItem: _moveLift,
          itemBuilder: (context, index) => Card(
            key: ValueKey(_liftOrder[index]),
            child: ListTile(
              key: Key('lift-order-$index'),
              title: Text(strings.lift(_liftOrder[index].name)),
              subtitle: _daysPerWeek == 4 && index < _sortedWeekdays.length
                  ? Text(strings.weekdayLong(_sortedWeekdays[index].isoValue))
                  : null,
              leading: IconButton(
                key: Key('move-lift-up-$index'),
                onPressed: index == 0
                    ? null
                    : () => _moveLift(index, index - 1),
                icon: const Icon(Icons.arrow_upward),
                tooltip: strings.moveUp,
              ),
              trailing: IconButton(
                key: Key('move-lift-down-$index'),
                onPressed: index == _liftOrder.length - 1
                    ? null
                    : () => _moveLift(index, index + 1),
                icon: const Icon(Icons.arrow_downward),
                tooltip: strings.moveDown,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          strings.schedulePreview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (preview.isNotEmpty) ...[
          Text('${strings.firstSession}: ${_dateLabel(preview.first.date)}'),
          Text('${strings.lastSession}: ${_dateLabel(preview.last.date)}'),
          Text(
            '${preview.length} ${strings.sessions} · 3 ${strings.programWeeks} · ${_calendarWeeks(preview)} ${strings.calendarWeeks}',
          ),
          for (final slot in preview.take(4))
            ListTile(
              dense: true,
              title: Text(_dateLabel(slot.date)),
              trailing: Text(strings.lift(slot.lift.name)),
            ),
        ],
      ],
    );
  }

  Widget _readyStep(AppStrings strings) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.check_circle_outline, size: 84),
      const SizedBox(height: 20),
      Text(strings.readyMessage, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.foundationProgram),
              const SizedBox(height: 8),
              Text('${strings.rulesGeneration}: Forever'),
              Text('${strings.mainWork}: Original 5/3/1'),
              Text('${strings.supplementalWork}: First Set Last 5 × 5'),
              Text('${strings.trainingMax}: 90 %'),
              Text('${strings.frequency}: $_daysPerWeek'),
              Text(
                '${strings.trainingDays}: ${_sortedWeekdays.map((day) => strings.weekdayLong(day.isoValue)).join(', ')}',
              ),
              Text(
                _daysPerWeek == 4
                    ? strings.fixedAssignments
                    : strings.rotationAcrossDays,
              ),
              Text(
                '${strings.liftOrder}: ${_liftOrder.map((lift) => strings.lift(lift.name)).join(' → ')}',
              ),
              if (_schedulePreview.isNotEmpty) ...[
                Text(
                  '${strings.firstSession}: ${_dateLabel(_schedulePreview.first.date)}',
                ),
                Text(
                  '${strings.lastSession}: ${_dateLabel(_schedulePreview.last.date)}',
                ),
                Text(
                  '${_schedulePreview.length} ${strings.sessions} · ${_calendarWeeks(_schedulePreview)} ${strings.calendarWeeks}',
                ),
              ],
              Text(
                '${strings.startDate}: ${MaterialLocalizations.of(context).formatMediumDate(_startDate)}',
              ),
              Text(
                '${strings.unit}: ${_unit == WeightUnit.kilograms ? 'kg' : 'lb'}',
              ),
              for (final lift in MainLift.values)
                Text(
                  '${strings.lift(lift.name)}: ${_maxes[lift]!.text} ${_unit == WeightUnit.kilograms ? 'kg' : 'lb'}',
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _validationStep(AppStrings strings) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        strings.validationMessage,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 18),
      for (final lift in MainLift.values)
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF5821F),
              foregroundColor: const Color(0xFF1A0E00),
              child: Text(strings.lift(lift.name).substring(0, 1)),
            ),
            title: Text(strings.lift(lift.name)),
            trailing: Text(
              '${_maxes[lift]!.text} ${_unit == WeightUnit.kilograms ? 'kg' : 'lb'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
    ],
  );

  Future<void> _continue() async {
    if (_step == 3 && !_formKey.currentState!.validate()) {
      return;
    }
    if (_step == 2 && _scheduleDefinition.validate().isNotEmpty) {
      return;
    }
    if (_step < 5) {
      if (_step == 1) {
        const catalog = ProgramCatalog();
        final preset = catalog.preset(_selectedPresetId);
        if (preset.availability != ProductAvailability.available) {
          return;
        }
      }
      setState(() => _step++);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSubmit(
        FoundationProfileInput(
          displayName: _name.text.trim(),
          unit: _unit,
          roundingIncrement: _unit == WeightUnit.kilograms ? 2.5 : 5,
          schedule: _scheduleDefinition,
          persistentPresetId: _selectedPresetId,
          presetVersion: const ProgramCatalog()
              .preset(_selectedPresetId)
              .version,
          oneRepMaxes: {
            for (final entry in _maxes.entries)
              entry.key: double.parse(entry.value.text.replaceAll(',', '.')),
          },
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'Création impossible. Vérifiez les valeurs puis réessayez.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<TrainingWeekday> get _sortedWeekdays =>
      [..._selectedWeekdays]
        ..sort((left, right) => left.isoValue.compareTo(right.isoValue));

  TrainingScheduleDefinition get _scheduleDefinition =>
      TrainingScheduleDefinition(
        startsOn: _startDate,
        frequency: _daysPerWeek,
        selectedWeekdays: _sortedWeekdays,
        liftOrder: _liftOrder,
        mode: _daysPerWeek == 4
            ? TrainingScheduleMode.fixedWeekdayAssignment
            : TrainingScheduleMode.rotatingAcrossSelectedDays,
        weekdayAssignments: _daysPerWeek == 4 && _selectedWeekdays.length == 4
            ? [
                for (var index = 0; index < 4; index++)
                  TrainingDayAssignment(
                    weekday: _sortedWeekdays[index],
                    lift: _liftOrder[index],
                  ),
              ]
            : const [],
      );

  List<ScheduledSessionSlot> get _schedulePreview {
    if (_scheduleDefinition.validate().isNotEmpty) return const [];
    return const SessionScheduleBuilder().build(_scheduleDefinition);
  }

  bool get _hasConsecutiveWarning {
    final values = _sortedWeekdays.map((day) => day.isoValue).toList();
    var run = 1;
    for (var index = 1; index < values.length; index++) {
      run = values[index] == values[index - 1] + 1 ? run + 1 : 1;
      if (run >= 3) return true;
    }
    return false;
  }

  void _changeFrequency(int frequency) {
    setState(() {
      _daysPerWeek = frequency;
      _selectedWeekdays = frequency == 4
          ? const [
              TrainingWeekday.monday,
              TrainingWeekday.tuesday,
              TrainingWeekday.thursday,
              TrainingWeekday.saturday,
            ]
          : const [
              TrainingWeekday.monday,
              TrainingWeekday.wednesday,
              TrainingWeekday.friday,
            ];
    });
  }

  void _toggleWeekday(TrainingWeekday day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays = [..._selectedWeekdays]..remove(day);
      } else if (_selectedWeekdays.length < _daysPerWeek) {
        _selectedWeekdays = [..._selectedWeekdays, day];
      }
    });
  }

  void _moveLift(int from, int to) {
    setState(() {
      final updated = [..._liftOrder];
      final lift = updated.removeAt(from);
      updated.insert(to, lift);
      _liftOrder = updated;
    });
  }

  void _setStartDate(DateTime value) =>
      setState(() => _startDate = DateTime(value.year, value.month, value.day));

  void _nextMonday() {
    final today = DateTime.now();
    final days = (DateTime.monday - today.weekday + 7) % 7;
    _setStartDate(today.add(Duration(days: days == 0 ? 7 : days)));
  }

  String _dateLabel(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);
  int _calendarWeeks(List<ScheduledSessionSlot> slots) =>
      slots.last.date.difference(slots.first.date).inDays ~/ 7 + 1;

  Future<void> _openLibrary({
    MethodGeneration? origin,
    bool showAll = false,
  }) async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ProgramLibraryScreen(
          mode: ProgramLibraryMode.select,
          selectedPresetId: _selectedPresetId,
          initialOrigin: origin,
          initialStatus: showAll
              ? ProgramStatusFilter.all
              : ProgramStatusFilter.current,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedPresetId = selected);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(() => _startDate = selected);
    }
  }
}
