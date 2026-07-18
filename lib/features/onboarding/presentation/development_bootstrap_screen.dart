import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

class DevelopmentBootstrapScreen extends StatefulWidget {
  const DevelopmentBootstrapScreen({required this.onSubmit, super.key});

  final Future<void> Function(FoundationProfileInput input) onSubmit;

  @override
  State<DevelopmentBootstrapScreen> createState() =>
      _DevelopmentBootstrapScreenState();
}

class _DevelopmentBootstrapScreenState
    extends State<DevelopmentBootstrapScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    return Scaffold(
      appBar: AppBar(title: Text(strings.developmentBootstrapTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.developmentBootstrapDescription),
            const Spacer(),
            FilledButton(
              key: const Key('create-development-demo'),
              onPressed: _saving ? null : _createDemo,
              child: Text(
                _saving ? strings.creating : strings.createDevelopmentDemo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDemo() async {
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        FoundationProfileInput(
          displayName: 'Athlète Démo',
          unit: WeightUnit.kilograms,
          oneRepMaxes: const {
            MainLift.squat: 100,
            MainLift.benchPress: 75,
            MainLift.deadlift: 125,
            MainLift.overheadPress: 50,
          },
          roundingIncrement: 2.5,
          startDate: DateTime(2026, 1, 5),
          trainingDaysPerWeek: 4,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
