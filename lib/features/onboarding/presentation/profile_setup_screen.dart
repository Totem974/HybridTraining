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
                  Text('${_step + 1}/4'),
                ],
              ),
            ),
            LinearProgressIndicator(value: (_step + 1) / 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _maxStep(strings),
                    1 => _programStep(strings),
                    2 => _scheduleStep(strings),
                    _ => _readyStep(strings),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
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
                      key: Key(_step == 3 ? 'create-cycle' : 'continue'),
                      onPressed: _saving ? null : _continue,
                      child: Text(
                        _saving
                            ? strings.creating
                            : _step == 3
                            ? strings.createCycle
                            : strings.continueLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: const Icon(Icons.fitness_center),
          title: Text(strings.foundationProgram),
          subtitle: Text(strings.foundationProgramDescription),
          trailing: const Icon(Icons.check_circle),
        ),
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

  Future<void> _continue() async {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    await widget.onSubmit(
      FoundationProfileInput(
        displayName: _name.text.trim(),
        unit: _unit,
        roundingIncrement: _unit == WeightUnit.kilograms ? 2.5 : 5,
        oneRepMaxes: {
          for (final entry in _maxes.entries)
            entry.key: double.parse(entry.value.text.replaceAll(',', '.')),
        },
      ),
    );
    if (mounted) setState(() => _saving = false);
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
