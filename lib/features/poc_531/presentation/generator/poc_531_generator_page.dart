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

class _GeneratorHero extends StatelessWidget {
  const _GeneratorHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF173F33), Color(0xFF286A55)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24102A22),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: const Wrap(
      spacing: 24,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONSTRUISEZ VOTRE CYCLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Charges, template, variante et planning dans un parcours unique. Chaque prescription affichée vient du CORE.',
                style: TextStyle(color: Color(0xFFD7E8E1), fontSize: 15),
              ),
            ],
          ),
        ),
        Chip(
          avatar: Icon(Icons.verified_outlined, size: 18),
          label: Text('CORE DÉTERMINISTE'),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: const Color(0x26102A22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFDDE6E1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
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
  bool projectFutureTrainingMaxes = true;
  bool busy = false;
  List<GeneratorWarning> warnings = const [];
  GeneratorResult? result;
  PlateLoadingView? plateLoading;

  List<ProgramChoice> get visiblePrograms => widget.core.options.programs
      .where((p) => status == 'all' || p.status == status)
      .toList(growable: false);

  ProgramChoice? get selectedProgram => widget.core.options.programs
      .where((program) => program.id == programId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _load(widget.initialConfiguration ?? const {});
    programId ??= visiblePrograms.firstOrNull?.id;
    generation = selectedProgram?.generation ?? generation;
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
    projectFutureTrainingMaxes =
        value['projectFutureTrainingMaxes'] as bool? ??
        projectFutureTrainingMaxes;
    final ratio = value['trainingMaxRatio'];
    if (ratio is num) ratioController.text = '${ratio.toDouble()}';
    final liftValues = value['lifts'];
    if (liftValues is Map) {
      for (final lift in lifts) {
        liftControllers[lift]!.text = '${liftValues[lift] ?? ''}';
      }
    }
    final repetitionValues = value['repetitions'];
    if (repetitionValues is Map) {
      for (final lift in lifts) {
        repsControllers[lift]!.text = '${repetitionValues[lift] ?? 1}';
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
    'projectFutureTrainingMaxes': projectFutureTrainingMaxes,
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
    backgroundColor: const Color(0xFFF3F6F4),
    appBar: AppBar(
      backgroundColor: const Color(0xFF10251F),
      foregroundColor: Colors.white,
      title: const Text('HYBRID 5/3/1'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: Center(child: Text('CALCULATEUR  •  POC')),
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final form = _buildForm(context);
        final output = _buildOutput(context);
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 12,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _GeneratorHero(),
                  const SizedBox(height: 22),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: form),
                        const SizedBox(width: 20),
                        Expanded(child: output),
                      ],
                    )
                  else ...[
                    form,
                    const SizedBox(height: 20),
                    output,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildForm(BuildContext context) => Form(
    key: formKey,
    child: _Surface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('01  CHARGES', style: _sectionStyle(context)),
          const Text(
            '1RM, Training Max direct ou performance multi-répétitions. Les calculs restent dans le CORE.',
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
                        key: ValueKey('reps-$lift'),
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
          Text('02  TEMPLATE & VARIANTE', style: _sectionStyle(context)),
          const Text(
            'Le template pilote la structure. Seules les définitions exécutables sont proposées.',
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
              setState(() {
                programId = v;
                generation = selectedProgram?.generation ?? generation;
              });
              _validate();
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                key: const Key('selected-generation'),
                avatar: const Icon(Icons.auto_stories_outlined, size: 18),
                label: Text(_generationLabel(generation)),
              ),
              if (selectedProgram case final program?)
                Chip(label: Text(program.status.toUpperCase())),
              ActionChip(
                key: const Key('status-filter'),
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(status == 'all' ? 'Tous les statuts' : status),
                onPressed: _cycleStatus,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('03  PLANNING', style: _sectionStyle(context)),
          const Text(
            'La fréquence est contrôlée par les règles de compatibilité du template.',
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
          const SizedBox(height: 24),
          Text('04  OPTIONS ADDITIONNELLES', style: _sectionStyle(context)),
          const Text(
            'Une option sans contrat structuré reste visible, verrouillée et expliquée.',
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _lockedOption(
                  'Warm-up',
                  Icons.local_fire_department_outlined,
                  'Selon le template CORE',
                ),
                _lockedOption(
                  'Joker Sets',
                  Icons.add_chart,
                  'Non documenté ici',
                ),
                _lockedOption(
                  'Deload',
                  Icons.low_priority,
                  'Selon la transition CORE',
                ),
              ];
              if (constraints.maxWidth < 560) {
                return Column(children: cards);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final card in cards) Expanded(child: card)],
              );
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
              onChanged: null,
            ),
          if (generation == 'beyond' || generation == 'forever')
            SwitchListTile(
              title: const Text('Projeter les futurs Training Max'),
              subtitle: const Text(
                'Utilise la progression sourcée comme projection visible ; une confirmation reste requise au checkpoint.',
              ),
              value: projectFutureTrainingMaxes,
              onChanged: (value) {
                setState(() => projectFutureTrainingMaxes = value);
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
    isExpanded: true,
    initialValue: values.contains(value) ? value : values.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: values.length == 1
        ? null
        : (v) {
            setState(() => assign(v!));
            _validate();
          },
  );

  Widget _buildOutput(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('05  PROGRAMME', style: _sectionStyle(context)),
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
        Text('06  MATÉRIEL', style: _sectionStyle(context)),
        const SizedBox(height: 6),
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

  TextStyle? _sectionStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
        color: const Color(0xFF173F33),
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      );

  Widget _lockedOption(String title, IconData icon, String value) => Padding(
    padding: const EdgeInsets.all(4),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EFEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2B725B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.lock_outline, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Color(0xFF60746C))),
        ],
      ),
    ),
  );

  String _generationLabel(String value) => switch (value) {
    'beyond' => 'Beyond 5/3/1',
    'forever' => '5/3/1 Forever',
    _ => 'Original — Second Edition',
  };

  void _cycleStatus() {
    const values = ['all', 'current', 'legacy', 'superseded'];
    setState(() {
      status = values[(values.indexOf(status) + 1) % values.length];
      if (!visiblePrograms.any((program) => program.id == programId)) {
        programId = visiblePrograms.firstOrNull?.id;
      }
      generation = selectedProgram?.generation ?? generation;
    });
    _validate();
  }

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
