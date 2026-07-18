import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

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
                    Text(_saveError!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                  ],
                  Row(children: [
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
                      onPressed: _saving ? null : _continue,
                      child: Text(
                        _saving
                            ? strings.creating
                            : _step == 5
                            ? strings.createCycle
                            : strings.continueLabel,
                      ),
                    ),
                  ),
                  ]),
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
          contentPadding: const EdgeInsets.all(18),
          leading: const Icon(Icons.fitness_center),
          title: Text(strings.foundationProgram),
          subtitle: Text(strings.foundationProgramDescription),
          trailing: const Icon(Icons.check_circle),
        ),
      ),
      const SizedBox(height: 16),
      SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text(strings.standardProgram)),
          ButtonSegment(
            value: 1,
            enabled: false,
            label: Text(strings.fullBodyProgram),
          ),
        ],
        selected: const {0},
        onSelectionChanged: (_) {},
      ),
      const SizedBox(height: 12),
      Text(strings.pocProgramNotice),
    ],
  );

  Widget _scheduleStep(AppStrings strings) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(strings.startPrompt, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(
            MaterialLocalizations.of(context).formatMediumDate(_startDate),
          ),
          subtitle: Text(strings.startDate),
          onTap: _pickDate,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        strings.frequencyPrompt,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 3, label: Text(strings.threeDays)),
          ButtonSegment(value: 4, label: Text(strings.fourDays)),
        ],
        selected: {_daysPerWeek},
        onSelectionChanged: (value) =>
            setState(() => _daysPerWeek = value.single),
      ),
    ],
  );

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
              Text('${strings.frequency}: $_daysPerWeek'),
              Text(
                '${strings.startDate}: ${MaterialLocalizations.of(context).formatMediumDate(_startDate)}',
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
    if (_step == 3 && !_formKey.currentState!.validate()) return;
    if (_step < 5) {
      setState(() => _step++);
      return;
    }
    setState(() { _saving = true; _saveError = null; });
    try {
      await widget.onSubmit(
      FoundationProfileInput(
        displayName: _name.text.trim(),
        unit: _unit,
        roundingIncrement: _unit == WeightUnit.kilograms ? 2.5 : 5,
        startDate: _startDate,
        trainingDaysPerWeek: _daysPerWeek,
        persistentPresetId: _selectedPresetId,
        oneRepMaxes: {
          for (final entry in _maxes.entries)
            entry.key: double.parse(entry.value.text.replaceAll(',', '.')),
        },
      ),
      );
    } catch (_) {
      if (mounted) setState(() => _saveError = 'Création impossible. Vérifiez les valeurs puis réessayez.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _startDate = selected);
  }
}
