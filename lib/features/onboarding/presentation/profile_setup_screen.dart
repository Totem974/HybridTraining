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
      appBar: AppBar(title: Text(strings.setupTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const Key('profile-name'),
                controller: _name,
                decoration: InputDecoration(labelText: strings.displayName),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<WeightUnit>(
                segments: const [
                  ButtonSegment(value: WeightUnit.kilograms, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.pounds, label: Text('lb')),
                ],
                selected: {_unit},
                onSelectionChanged: (value) =>
                    setState(() => _unit = value.single),
              ),
              const SizedBox(height: 24),
              Text(strings.maxInstructions),
              const SizedBox(height: 8),
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
                          ? 'Valeur positive obligatoire'
                          : null;
                    },
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(strings.selectedProgram),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('create-cycle'),
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Création…' : strings.createCycle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSubmit(
      FoundationProfileInput(
        displayName: _name.text,
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
}
