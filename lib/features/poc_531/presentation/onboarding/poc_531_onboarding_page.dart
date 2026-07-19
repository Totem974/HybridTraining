import 'package:flutter/material.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;

class Poc531OnboardingPage extends StatefulWidget {
  const Poc531OnboardingPage({required this.onProgramSelected, super.key});

  /// Integration point for navigation to the generator.
  /// The receiving page must use this exact CORE configuration.
  final ValueChanged<core.ProgramConfiguration> onProgramSelected;

  @override
  State<Poc531OnboardingPage> createState() => _Poc531OnboardingPageState();
}

class _Poc531OnboardingPageState extends State<Poc531OnboardingPage> {
  static const _liftLabels = {
    core.MainLift.overheadPress: 'Press',
    core.MainLift.benchPress: 'Bench Press',
    core.MainLift.squat: 'Squat',
    core.MainLift.deadlift: 'Deadlift',
  };

  final _liftControllers = {
    for (final lift in core.MainLift.values) lift: TextEditingController(),
  };
  final _liftFormKey = GlobalKey<FormState>();
  int _step = 0;
  core.TrainingGoal _goal = core.TrainingGoal.strength;
  core.ExperienceLevel _level = core.ExperienceLevel.intermediate;
  int _days = 4;
  int _minutes = 60;
  bool _hasBarbell = true;
  bool _hasRack = true;
  bool _hasConditioningEquipment = false;
  String _conditioning = 'Modéré';
  core.Generation? _generation;
  bool _allowLegacy = false;
  core.WeightUnit _unit = core.WeightUnit.kilograms;
  List<core.Recommendation> _recommendations = const [];

  @override
  void dispose() {
    for (final controller in _liftControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('poc-531-onboarding'),
    appBar: AppBar(title: const Text('Trouver mon programme 5/3/1')),
    body: SafeArea(
      child: Stepper(
        currentStep: _step,
        type: StepperType.vertical,
        onStepTapped: (value) {
          if (value <= _step) setState(() => _step = value);
        },
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        onStepContinue: _continue,
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            spacing: 8,
            children: [
              if (_step < 9)
                FilledButton(
                  key: const Key('onboarding-continue'),
                  onPressed: details.onStepContinue,
                  child: Text(
                    _step == 8 ? 'Voir mes recommandations' : 'Continuer',
                  ),
                ),
              if (_step > 0)
                TextButton(
                  key: const Key('onboarding-back'),
                  onPressed: details.onStepCancel,
                  child: const Text('Retour'),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Accueil'),
            isActive: _step >= 0,
            content: _panel(
              title: 'Un programme adapté, sans devinette',
              body:
                  'Répondez à quelques questions. Les recommandations et les compatibilités proviennent du même CORE que le générateur.',
              icon: Icons.explore_outlined,
            ),
          ),
          Step(
            title: const Text('Objectif'),
            isActive: _step >= 1,
            content: _enumChoice<core.TrainingGoal>(
              label: 'Objectif principal',
              value: _goal,
              values: core.TrainingGoal.values,
              text: _goalLabel,
              onChanged: (value) => setState(() => _goal = value),
            ),
          ),
          Step(
            title: const Text('Expérience'),
            isActive: _step >= 2,
            content: _enumChoice<core.ExperienceLevel>(
              label: 'Niveau actuel',
              value: _level,
              values: core.ExperienceLevel.values,
              text: _levelLabel,
              onChanged: (value) => setState(() => _level = value),
            ),
          ),
          Step(
            title: const Text('Disponibilité'),
            isActive: _step >= 3,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_days jours par semaine'),
                Slider(
                  key: const Key('onboarding-days'),
                  value: _days.toDouble(),
                  min: 2,
                  max: 4,
                  divisions: 2,
                  label: '$_days jours',
                  onChanged: (value) => setState(() => _days = value.round()),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _minutes,
                  decoration: const InputDecoration(
                    labelText: 'Durée approximative par séance',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 45, child: Text('45 minutes')),
                    DropdownMenuItem(value: 60, child: Text('60 minutes')),
                    DropdownMenuItem(
                      value: 75,
                      child: Text('75 minutes ou plus'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _minutes = value!),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Matériel'),
            isActive: _step >= 4,
            content: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Barre et disques'),
                  value: _hasBarbell,
                  onChanged: (value) => setState(() => _hasBarbell = value!),
                ),
                CheckboxListTile(
                  title: const Text('Rack ou supports sécurisés'),
                  value: _hasRack,
                  onChanged: (value) => setState(() => _hasRack = value!),
                ),
                CheckboxListTile(
                  title: const Text('Matériel de conditioning'),
                  value: _hasConditioningEquipment,
                  onChanged: (value) =>
                      setState(() => _hasConditioningEquipment = value!),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Conditioning'),
            isActive: _step >= 5,
            content: _enumChoice<String>(
              label: 'Conditioning souhaité ou toléré',
              value: _conditioning,
              values: const ['Minimal', 'Modéré', 'Prioritaire'],
              text: (value) => value,
              onChanged: (value) => setState(() => _conditioning = value),
            ),
          ),
          Step(
            title: const Text('Lifts'),
            isActive: _step >= 6,
            content: Form(
              key: _liftFormKey,
              child: Column(
                children: [
                  SegmentedButton<core.WeightUnit>(
                    segments: const [
                      ButtonSegment(
                        value: core.WeightUnit.kilograms,
                        label: Text('kg'),
                      ),
                      ButtonSegment(
                        value: core.WeightUnit.pounds,
                        label: Text('lb'),
                      ),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (value) =>
                        setState(() => _unit = value.first),
                  ),
                  const SizedBox(height: 12),
                  for (final entry in _liftLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey('onboarding-lift-${entry.key.name}'),
                        controller: _liftControllers[entry.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${entry.value} — 1RM (${_unit == core.WeightUnit.kilograms ? 'kg' : 'lb'})',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          return parsed == null || parsed <= 0
                              ? 'Saisissez un 1RM positif'
                              : null;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Génération'),
            isActive: _step >= 7,
            content: _enumChoice<core.Generation?>(
              label: 'Préférence de génération',
              value: _generation,
              values: const [
                null,
                core.Generation.original,
                core.Generation.beyond,
                core.Generation.forever,
              ],
              text: (value) => value == null
                  ? 'Recommander pour moi'
                  : _generationLabel(value),
              onChanged: (value) => setState(() => _generation = value),
            ),
          ),
          Step(
            title: const Text('Legacy'),
            isActive: _step >= 8,
            content: SwitchListTile(
              title: const Text('Autoriser les programmes Legacy'),
              subtitle: const Text(
                'Ils seront clairement identifiés dans les résultats.',
              ),
              value: _allowLegacy,
              onChanged: (value) => setState(() => _allowLegacy = value),
            ),
          ),
          Step(
            title: const Text('Résultats'),
            isActive: _step >= 9,
            content: _results(context),
          ),
        ],
      ),
    ),
  );

  Widget _panel({
    required String title,
    required String body,
    required IconData icon,
  }) => Semantics(
    header: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  Widget _enumChoice<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(text(item))),
    ],
    onChanged: (next) => onChanged(next as T),
  );

  Widget _results(BuildContext context) {
    if (_recommendations.isEmpty) {
      return Semantics(
        liveRegion: true,
        child: const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Aucun programme compatible'),
            subtitle: Text(
              'Le CORE ne trouve aucun template exécutable avec ces contraintes. Revenez modifier la disponibilité, le matériel ou Legacy.',
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _recommendations.length >= 3
              ? '${_recommendations.length} recommandations classées'
              : 'Seulement ${_recommendations.length} programme(s) compatible(s) dans le catalogue exécutable actuel.',
          key: const Key('recommendation-count'),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _recommendations.length; index++)
          _recommendationCard(context, _recommendations[index], index),
      ],
    );
  }

  Widget _recommendationCard(
    BuildContext context,
    core.Recommendation recommendation,
    int index,
  ) {
    final program = recommendation.program;
    return Card(
      key: ValueKey('recommendation-${program.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('#${index + 1} · score ${recommendation.score}'),
                ),
                Chip(label: Text(_generationLabel(program.generation!))),
                Chip(label: Text(program.status.name.toUpperCase())),
                Chip(label: Text('${program.frequencies.join('/')} j/sem.')),
              ],
            ),
            Text(program.name, style: Theme.of(context).textTheme.titleLarge),
            Text('${program.family} · ${program.variant}'),
            const SizedBox(height: 8),
            if (recommendation.reasons.isNotEmpty)
              Text('Points forts : ${recommendation.reasons.join(' · ')}'),
            if (recommendation.tradeoffs.isNotEmpty)
              Text('Compromis : ${recommendation.tradeoffs.join(' · ')}'),
            if (program.requiresLeaderAnchor)
              const Text('Structure Leader / Anchor et 7th Week requise.'),
            const SizedBox(height: 12),
            FilledButton(
              key: ValueKey('select-${program.id}'),
              onPressed: () => _select(recommendation),
              child: const Text('Choisir et ouvrir le générateur'),
            ),
          ],
        ),
      ),
    );
  }

  void _continue() {
    if (_step == 6 && !(_liftFormKey.currentState?.validate() ?? false)) return;
    if (_step == 8) {
      _recommend();
      setState(() => _step = 9);
      return;
    }
    if (_step < 9) setState(() => _step++);
  }

  void _recommend() {
    final profile = core.UserProfile(
      goal: _goal,
      level: _level,
      preferredGeneration: _generation,
      constraints: core.UserConstraints(
        daysPerWeek: _days,
        allowLegacy: _allowLegacy,
        hasBarbell: _hasBarbell && _hasRack,
      ),
    );
    _recommendations = core.recommendPrograms(profile);
  }

  void _select(core.Recommendation recommendation) {
    final program = recommendation.program;
    final configuration = core.ProgramConfiguration(
      programId: program.id,
      generation: program.generation!,
      unit: _unit,
      lifts: {
        for (final lift in core.MainLift.values)
          lift: core.LiftInput(
            lift: lift,
            kind: core.LiftInputKind.oneRepMax,
            weight: double.parse(
              _liftControllers[lift]!.text.replaceAll(',', '.'),
            ),
          ),
      },
      trainingMaxRatio: 0.9,
      daysPerWeek: _days,
      trainingWeekdays: List<int>.generate(_days, (index) => index + 1),
      startDate: DateTime.utc(2026, 1, 5),
    );
    final issues = core.validateProgramConfiguration(configuration);
    if (issues.any((issue) => issue.blocking)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(issues.map((issue) => issue.message).join(' '))),
      );
      return;
    }
    widget.onProgramSelected(configuration);
  }

  String _goalLabel(core.TrainingGoal value) => switch (value) {
    core.TrainingGoal.strength => 'Force',
    core.TrainingGoal.hypertrophy => 'Hypertrophie',
    core.TrainingGoal.generalPreparation => 'Préparation générale',
    core.TrainingGoal.reducedFrequency => 'Fréquence réduite',
    core.TrainingGoal.powerliftingPreparation =>
      'Préparation powerlifting (extension)',
  };

  String _levelLabel(core.ExperienceLevel value) => switch (value) {
    core.ExperienceLevel.beginner => 'Débutant',
    core.ExperienceLevel.intermediate => 'Intermédiaire',
    core.ExperienceLevel.advanced => 'Avancé',
  };

  String _generationLabel(core.Generation value) => switch (value) {
    core.Generation.original => 'Original — Second Edition',
    core.Generation.beyond => 'Beyond 5/3/1',
    core.Generation.forever => '5/3/1 Forever',
  };
}
