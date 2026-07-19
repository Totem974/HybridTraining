import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class Poc531GeneratorCore {
  GeneratorOptions get options;
  Future<GeneratorResult> generate(Map<String, Object?> configuration);
  Future<List<GeneratorWarning>> validate(Map<String, Object?> configuration);
  Future<String> serializeConfiguration(Map<String, Object?> configuration);
  Future<PlateLoadingView> calculatePlateLoading({
    required double weight,
    required double barWeight,
    required List<double> inventory,
    required String unit,
  });
}

class GeneratorOptions {
  const GeneratorOptions({
    required this.programs,
    this.supplemental = const ['Aucun'],
    this.assistance = const ['Minimal'],
    this.conditioning = const ['Optionnel'],
    this.transitions = const ['Selon le programme'],
  });
  final List<ProgramChoice> programs;
  final List<String> supplemental;
  final List<String> assistance;
  final List<String> conditioning;
  final List<String> transitions;
}

class ProgramChoice {
  const ProgramChoice({
    required this.id,
    required this.name,
    required this.generation,
    required this.family,
    required this.variant,
    required this.status,
  });
  final String id;
  final String name;
  final String generation;
  final String family;
  final String variant;
  final String status;
}

class GeneratorWarning {
  const GeneratorWarning(this.message, {this.isError = false});
  final String message;
  final bool isError;
}

class GeneratorResult {
  const GeneratorResult({
    required this.title,
    required this.blocks,
    this.explanation = '',
    this.sources = const [],
    this.warnings = const [],
    this.exportJson = '',
  });
  final String title;
  final List<PlanBlockView> blocks;
  final String explanation;
  final List<String> sources;
  final List<GeneratorWarning> warnings;
  final String exportJson;
}

class PlanBlockView {
  const PlanBlockView(this.name, this.weeks);
  final String name;
  final List<PlanWeekView> weeks;
}

class PlanWeekView {
  const PlanWeekView(this.name, this.sessions);
  final String name;
  final List<PlanSessionView> sessions;
}

class PlanSessionView {
  const PlanSessionView(this.name, this.prescriptions);
  final String name;
  final List<String> prescriptions;
}

class PlateLoadingView {
  const PlateLoadingView({
    required this.perSide,
    required this.actualWeight,
    required this.roundingError,
  });
  final List<double> perSide;
  final double actualWeight;
  final double roundingError;
}

class Poc531GeneratorPage extends StatefulWidget {
  const Poc531GeneratorPage({
    required this.core,
    this.initialConfiguration,
    super.key,
  });
  final Poc531GeneratorCore core;
  final Map<String, Object?>? initialConfiguration;

  @override
  State<Poc531GeneratorPage> createState() => _Poc531GeneratorPageState();
}

class _Poc531GeneratorPageState extends State<Poc531GeneratorPage> {
  static const lifts = ['Press', 'Bench Press', 'Squat', 'Deadlift'];
  final formKey = GlobalKey<FormState>();
  final liftControllers = {
    for (final lift in lifts) lift: TextEditingController(),
  };
  final repsControllers = {
    for (final lift in lifts) lift: TextEditingController(text: '1'),
  };
  final ratioController = TextEditingController(text: '90');
  final barController = TextEditingController(text: '20');
  final platesController = TextEditingController(
    text: '25,20,15,10,5,2.5,1.25',
  );
  String unit = 'kg';
  String inputMode = '1RM';
  String generation = 'original';
  String status = 'all';
  String? programId;
  String supplemental = 'Aucun';
  String assistance = 'Minimal';
  String conditioning = 'Optionnel';
  String transition = 'Selon le programme';
  int days = 4;
  bool foreverLeaderAnchor = true;
  bool busy = false;
  List<GeneratorWarning> warnings = const [];
  GeneratorResult? result;
  PlateLoadingView? plateLoading;

  List<ProgramChoice> get visiblePrograms => widget.core.options.programs
      .where(
        (p) =>
            p.generation == generation &&
            (status == 'all' || p.status == status),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load(widget.initialConfiguration ?? const {});
    programId ??= visiblePrograms.firstOrNull?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
  }

  @override
  void dispose() {
    for (final controller in [
      ...liftControllers.values,
      ...repsControllers.values,
    ]) {
      controller.dispose();
    }
    ratioController.dispose();
    barController.dispose();
    platesController.dispose();
    super.dispose();
  }

  void _load(Map<String, Object?> value) {
    unit = value['unit'] as String? ?? unit;
    inputMode = value['inputMode'] as String? ?? inputMode;
    generation = value['generation'] as String? ?? generation;
    status = value['status'] as String? ?? status;
    programId = value['programId'] as String?;
    days = value['days'] as int? ?? days;
    final liftValues = value['lifts'];
    if (liftValues is Map) {
      for (final lift in lifts) {
        liftControllers[lift]!.text = '${liftValues[lift] ?? ''}';
      }
    }
  }

  Map<String, Object?> get configuration => {
    'schemaVersion': 1,
    'unit': unit,
    'inputMode': inputMode,
    'trainingMaxRatio': double.tryParse(ratioController.text),
    'generation': generation,
    'status': status,
    'programId': programId,
    'days': days,
    'supplemental': supplemental,
    'assistance': assistance,
    'conditioning': conditioning,
    'transition': transition,
    'leaderAnchor': foreverLeaderAnchor,
    'lifts': {
      for (final lift in lifts)
        lift: double.tryParse(liftControllers[lift]!.text),
    },
    'repetitions': {
      for (final lift in lifts) lift: int.tryParse(repsControllers[lift]!.text),
    },
  };

  Future<void> _validate() async {
    final next = await widget.core.validate(configuration);
    if (mounted) setState(() => warnings = next);
  }

  Future<void> _generate() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      final next = await widget.core.generate(configuration);
      if (mounted) setState(() => result = next);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('poc-531-generator'),
    appBar: AppBar(title: const Text('Générateur 5/3/1 — POC')),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final form = _buildForm(context);
        final output = _buildOutput(context);
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: form),
                  const VerticalDivider(width: 1),
                  Expanded(child: output),
                ],
              )
            : ListView(children: [form, output]);
      },
    ),
  );

  Widget _buildForm(BuildContext context) => Form(
    key: formKey,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configurer les charges',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Toutes les prescriptions et compatibilités sont calculées par le CORE.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'kg', label: Text('kg')),
              ButtonSegment(value: 'lb', label: Text('lb')),
            ],
            selected: {unit},
            onSelectionChanged: (v) {
              setState(() => unit = v.first);
              _validate();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('input-mode'),
            initialValue: inputMode,
            decoration: const InputDecoration(
              labelText: 'Mode de saisie',
              border: OutlineInputBorder(),
            ),
            items: const [
              '1RM',
              'Training Max',
              'Rep max',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => inputMode = v!),
          ),
          const SizedBox(height: 12),
          for (final lift in lifts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('lift-$lift'),
                      controller: liftControllers[lift],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '$lift ($unit)',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Saisissez une charge positive'
                          : null,
                      onChanged: (_) => _validate(),
                    ),
                  ),
                  if (inputMode == 'Rep max') ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: repsControllers[lift],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Rép.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          TextFormField(
            key: const Key('tm-ratio'),
            controller: ratioController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ratio Training Max (%)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _validate(),
          ),
          const SizedBox(height: 24),
          Text(
            'Choisir le programme',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('generation'),
            isExpanded: true,
            initialValue: generation,
            decoration: const InputDecoration(
              labelText: 'Génération',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'original',
                child: Text('Original — Second Edition'),
              ),
              DropdownMenuItem(value: 'beyond', child: Text('Beyond 5/3/1')),
              DropdownMenuItem(value: 'forever', child: Text('5/3/1 Forever')),
            ],
            onChanged: (v) {
              setState(() {
                generation = v!;
                programId = visiblePrograms.firstOrNull?.id;
              });
              _validate();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('status-filter'),
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Statut',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'current', child: Text('Current')),
              DropdownMenuItem(value: 'legacy', child: Text('Legacy')),
              DropdownMenuItem(value: 'all', child: Text('Tous')),
            ],
            onChanged: (v) {
              setState(() {
                status = v!;
                programId = visiblePrograms.firstOrNull?.id;
              });
              _validate();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('program'),
            isExpanded: true,
            initialValue: visiblePrograms.any((p) => p.id == programId)
                ? programId
                : null,
            decoration: const InputDecoration(
              labelText: 'Famille · programme · variante',
              border: OutlineInputBorder(),
            ),
            items: visiblePrograms
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.family} · ${p.name} · ${p.variant}'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => programId = v);
              _validate();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: days,
            decoration: const InputDecoration(
              labelText: 'Séances par semaine',
              border: OutlineInputBorder(),
            ),
            items: [2, 3, 4]
                .map((v) => DropdownMenuItem(value: v, child: Text('$v jours')))
                .toList(),
            onChanged: (v) {
              setState(() => days = v!);
              _validate();
            },
          ),
          const SizedBox(height: 12),
          _choice(
            'Supplemental',
            supplemental,
            widget.core.options.supplemental,
            (v) => supplemental = v,
          ),
          const SizedBox(height: 12),
          _choice(
            'Assistance',
            assistance,
            widget.core.options.assistance,
            (v) => assistance = v,
          ),
          const SizedBox(height: 12),
          _choice(
            'Conditioning',
            conditioning,
            widget.core.options.conditioning,
            (v) => conditioning = v,
          ),
          const SizedBox(height: 12),
          _choice(
            'Deload / transition',
            transition,
            widget.core.options.transitions,
            (v) => transition = v,
          ),
          if (generation == 'forever')
            SwitchListTile(
              title: const Text('Structure Leader / Anchor et 7th Week'),
              subtitle: const Text(
                'Appliquée uniquement lorsque la définition CORE l’exige.',
              ),
              value: foreverLeaderAnchor,
              onChanged: (v) {
                setState(() => foreverLeaderAnchor = v);
                _validate();
              },
            ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...warnings.map(
              (w) => Semantics(
                liveRegion: true,
                child: Card(
                  color: w.isError
                      ? Theme.of(context).colorScheme.errorContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: Icon(
                      w.isError ? Icons.error_outline : Icons.info_outline,
                    ),
                    title: Text(w.message),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('generate-program'),
                onPressed: busy || warnings.any((w) => w.isError)
                    ? null
                    : _generate,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Générer'),
              ),
              OutlinedButton(
                onPressed: _loadExample,
                child: const Text('Charger un exemple'),
              ),
              TextButton(onPressed: _reset, child: const Text('Réinitialiser')),
              OutlinedButton.icon(
                onPressed: _copyConfiguration,
                icon: const Icon(Icons.link),
                label: const Text('Copier la configuration'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _choice(
    String label,
    String value,
    List<String> values,
    void Function(String) assign,
  ) => DropdownButtonFormField<String>(
    initialValue: values.contains(value) ? value : values.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: (v) {
      setState(() => assign(v!));
      _validate();
    },
  );

  Widget _buildOutput(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Programme généré',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (result == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('Le résultat apparaîtra ici après validation.'),
            ),
          )
        else ...[
          Text(result!.title, style: Theme.of(context).textTheme.titleLarge),
          if (result!.explanation.isNotEmpty) Text(result!.explanation),
          const SizedBox(height: 12),
          for (final block in result!.blocks)
            ExpansionTile(
              key: ValueKey('block-${block.name}'),
              initiallyExpanded: true,
              title: Text(block.name),
              children: [
                for (final week in block.weeks)
                  ExpansionTile(
                    key: ValueKey('week-${week.name}'),
                    initiallyExpanded: true,
                    title: Text(week.name),
                    children: [
                      for (final session in week.sessions)
                        Card(
                          child: ListTile(
                            title: Text(session.name),
                            subtitle: Text(session.prescriptions.join('\n')),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          if (result!.sources.isNotEmpty)
            ExpansionTile(
              title: const Text('Sources et pages'),
              children: result!.sources
                  .map(
                    (s) => ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(s),
                    ),
                  )
                  .toList(),
            ),
          ...result!.warnings.map(
            (w) => ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text(w.message),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('export-json'),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: result!.exportJson)),
                icon: const Icon(Icons.data_object),
                label: const Text('Copier export JSON'),
              ),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Utilisez la commande d’impression du navigateur.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.print),
                label: const Text('Imprimer'),
              ),
            ],
          ),
        ],
        const Divider(height: 40),
        ExpansionTile(
          key: const Key('plate-panel'),
          title: const Text('Chargement de la barre'),
          subtitle: const Text('Plaques par côté et erreur d’arrondi'),
          children: [
            TextField(
              controller: barController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Poids de la barre ($unit)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: platesController,
              decoration: const InputDecoration(
                labelText: 'Inventaire des plaques (séparé par des virgules)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _calculatePlates,
              child: const Text('Calculer le chargement'),
            ),
            if (plateLoading != null)
              ListTile(
                title: Text(
                  'Par côté : ${plateLoading!.perSide.join(' + ')} $unit',
                ),
                subtitle: Text(
                  'Charge réelle : ${plateLoading!.actualWeight} $unit · écart : ${plateLoading!.roundingError} $unit',
                ),
              ),
          ],
        ),
      ],
    ),
  );

  void _loadExample() {
    setState(() {
      unit = 'kg';
      inputMode = '1RM';
      ratioController.text = '90';
      final values = [60, 90, 120, 150];
      for (var i = 0; i < lifts.length; i++) {
        liftControllers[lifts[i]]!.text = '${values[i]}';
      }
    });
    _validate();
  }

  void _reset() {
    for (final c in liftControllers.values) {
      c.clear();
    }
    setState(() {
      result = null;
      warnings = const [];
      unit = 'kg';
      inputMode = '1RM';
      ratioController.text = '90';
    });
    _validate();
  }

  Future<void> _copyConfiguration() async {
    final payload = await widget.core.serializeConfiguration(configuration);
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuration copiée')));
    }
  }

  Future<void> _calculatePlates() async {
    final target =
        result?.blocks.firstOrNull?.weeks.firstOrNull?.sessions.firstOrNull ==
            null
        ? double.tryParse(liftControllers.values.first.text)
        : double.tryParse(liftControllers.values.first.text);
    final inventory = platesController.text
        .split(',')
        .map((v) => double.tryParse(v.trim()))
        .whereType<double>()
        .toList();
    if (target == null) return;
    final value = await widget.core.calculatePlateLoading(
      weight: target,
      barWeight: double.tryParse(barController.text) ?? 20,
      inventory: inventory,
      unit: unit,
    );
    if (mounted) setState(() => plateLoading = value);
  }
}
