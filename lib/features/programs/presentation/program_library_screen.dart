import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/programs/domain/program_library.dart';

enum ProgramLibraryMode { browse, select }

enum ProgramStatusFilter { current, legacy, all }

enum _LibraryTab { programs, components, protocols, history }

class ProgramLibraryScreen extends StatefulWidget {
  const ProgramLibraryScreen({
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
    this.initialOrigin,
    this.initialStatus = ProgramStatusFilter.current,
    this.repository = const InMemoryProgramLibraryRepository(),
    super.key,
  });
  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;
  final MethodGeneration? initialOrigin;
  final ProgramStatusFilter initialStatus;
  final ProgramLibraryRepository repository;

  @override
  State<ProgramLibraryScreen> createState() => _ProgramLibraryScreenState();
}

class _ProgramLibraryScreenState extends State<ProgramLibraryScreen> {
  _LibraryTab tab = _LibraryTab.programs;
  String search = '';
  ProgramLibrarySort sort = ProgramLibrarySort.recommendation;
  MethodGeneration? origin;
  MethodGeneration? generation;
  ForeverStatus? foreverStatus;
  ProgramPhase? phase;
  ProgramLevel? level;
  ProgramGoal? goal;
  int? frequency;
  int? mainMovements;
  ProgramEquipment? equipment;
  ProgramTmRange? tmRange;
  ProgramValidationStatus? documentation;
  ProgramImplementationStatus? implementation;

  @override
  void initState() {
    super.initState();
    origin = widget.initialOrigin;
    if (widget.initialStatus == ProgramStatusFilter.legacy) {
      tab = _LibraryTab.history;
    }
  }

  Set<ProgramEntryKind> get _kinds => switch (tab) {
    _LibraryTab.programs => {ProgramEntryKind.program, ProgramEntryKind.preset},
    _LibraryTab.components => {ProgramEntryKind.component},
    _LibraryTab.protocols => {ProgramEntryKind.protocol},
    _LibraryTab.history => {ProgramEntryKind.revision},
  };

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final result = widget.repository.query(
      ProgramQuery(
        search: search,
        sort: sort,
        filter: ProgramFilter(
          kinds: _kinds,
          origins: origin == null ? const {} : {origin!},
          generations: generation == null ? const {} : {generation!},
          foreverStatuses: foreverStatus == null ? const {} : {foreverStatus!},
          phases: phase == null ? const {} : {phase!},
          levels: level == null ? const {} : {level!},
          goals: goal == null ? const {} : {goal!},
          frequencies: frequency == null ? const {} : {frequency!},
          mainMovementsPerSession: mainMovements == null
              ? const {}
              : {mainMovements!},
          equipment: equipment == null ? const {} : {equipment!},
          tmRange: tmRange,
          documentationStatuses: documentation == null
              ? const {}
              : {documentation!},
          implementationStatuses: implementation == null
              ? const {}
              : {implementation!},
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.library)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<_LibraryTab>(
              segments: const [
                ButtonSegment(
                  value: _LibraryTab.programs,
                  label: Text('Programmes'),
                ),
                ButtonSegment(
                  value: _LibraryTab.components,
                  label: Text('Composants'),
                ),
                ButtonSegment(
                  value: _LibraryTab.protocols,
                  label: Text('Protocoles'),
                ),
                ButtonSegment(
                  value: _LibraryTab.history,
                  label: Text('Historique'),
                ),
              ],
              selected: {tab},
              onSelectionChanged: (value) => setState(() => tab = value.single),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('program-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Rechercher',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('open-program-filters'),
                    onPressed: () => _showFilters(context),
                    icon: const Icon(Icons.tune),
                    label: const Text('Filtres'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ProgramLibrarySort>(
                    key: const Key('program-sort'),
                    initialValue: sort,
                    decoration: const InputDecoration(labelText: 'Trier par'),
                    isExpanded: true,
                    items: ProgramLibrarySort.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              _sortLabel(value),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => sort = value!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: result.entries.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun résultat. Modifiez votre recherche ou vos filtres.',
                      key: Key('empty-program-filter'),
                    ),
                  )
                : ListView.builder(
                    key: const Key('program-library-list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: result.entries.length,
                    itemBuilder: (context, index) => _EntryCard(
                      entry: result.entries[index],
                      mode: widget.mode,
                      activePresetId: widget.activePresetId,
                      selectedPresetId: widget.selectedPresetId,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    var draftOrigin = origin;
    var draftGeneration = generation;
    var draftForeverStatus = foreverStatus;
    var draftPhase = phase;
    var draftLevel = level;
    var draftGoal = goal;
    var draftFrequency = frequency;
    var draftMainMovements = mainMovements;
    var draftEquipment = equipment;
    var draftTmRange = tmRange;
    var draftDocumentation = documentation;
    var draftImplementation = implementation;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
                _filterDropdown<MethodGeneration>(
                  key: 'filter-origin',
                  label: 'Origine',
                  value: draftOrigin,
                  values: MethodGeneration.values,
                  text: (v) => _generation(v),
                  onChanged: (v) => update(() => draftOrigin = v),
                ),
                _filterDropdown<ProgramLevel>(
                  key: 'filter-level',
                  label: 'Niveau',
                  value: draftLevel,
                  values: ProgramLevel.values,
                  text: _levelLabel,
                  onChanged: (v) => update(() => draftLevel = v),
                ),
                _filterDropdown<MethodGeneration>(
                  key: 'filter-generation',
                  label: 'Génération de révision',
                  value: draftGeneration,
                  values: MethodGeneration.values,
                  text: _generation,
                  onChanged: (v) => update(() => draftGeneration = v),
                ),
                _filterDropdown<ForeverStatus>(
                  key: 'filter-forever-status',
                  label: 'Statut Forever',
                  value: draftForeverStatus,
                  values: ForeverStatus.values,
                  text: _foreverStatusLabel,
                  onChanged: (v) => update(() => draftForeverStatus = v),
                ),
                _filterDropdown<ProgramPhase>(
                  key: 'filter-phase',
                  label: 'Phase',
                  value: draftPhase,
                  values: ProgramPhase.values,
                  text: _phaseLabel,
                  onChanged: (v) => update(() => draftPhase = v),
                ),
                _filterDropdown<int>(
                  key: 'filter-frequency',
                  label: 'Fréquence',
                  value: draftFrequency,
                  values: const [3, 4],
                  text: (v) => '$v jours',
                  onChanged: (v) => update(() => draftFrequency = v),
                ),
                _filterDropdown<ProgramGoal>(
                  key: 'filter-goal',
                  label: 'Objectif',
                  value: draftGoal,
                  values: ProgramGoal.values,
                  text: _goalLabel,
                  onChanged: (v) => update(() => draftGoal = v),
                ),
                _filterDropdown<int>(
                  key: 'filter-main-movements',
                  label: 'Mouvements principaux par séance',
                  value: draftMainMovements,
                  values: const [1, 2],
                  text: (v) => '$v',
                  onChanged: (v) => update(() => draftMainMovements = v),
                ),
                _filterDropdown<ProgramEquipment>(
                  key: 'filter-equipment',
                  label: 'Équipement',
                  value: draftEquipment,
                  values: ProgramEquipment.values,
                  text: _equipmentLabel,
                  onChanged: (v) => update(() => draftEquipment = v),
                ),
                _filterDropdown<ProgramTmRange>(
                  key: 'filter-tm-range',
                  label: 'Plage de Training Max',
                  value: draftTmRange,
                  values: const [
                    ProgramTmRange(.80, .85),
                    ProgramTmRange(.85, .90),
                    ProgramTmRange(.90, .90),
                  ],
                  text: (v) =>
                      '${(v.minimum * 100).round()}–${(v.maximum * 100).round()} %',
                  onChanged: (v) => update(() => draftTmRange = v),
                ),
                _filterDropdown<ProgramValidationStatus>(
                  key: 'filter-documentation',
                  label: 'Statut documentaire',
                  value: draftDocumentation,
                  values: ProgramValidationStatus.values,
                  text: _documentationLabel,
                  onChanged: (v) => update(() => draftDocumentation = v),
                ),
                _filterDropdown<ProgramImplementationStatus>(
                  key: 'filter-implementation',
                  label: 'Statut d’implémentation',
                  value: draftImplementation,
                  values: ProgramImplementationStatus.values,
                  text: _implementationLabel,
                  onChanged: (v) => update(() => draftImplementation = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => update(() {
                        draftOrigin = null;
                        draftGeneration = null;
                        draftForeverStatus = null;
                        draftPhase = null;
                        draftLevel = null;
                        draftGoal = null;
                        draftFrequency = null;
                        draftMainMovements = null;
                        draftEquipment = null;
                        draftTmRange = null;
                        draftDocumentation = null;
                        draftImplementation = null;
                      }),
                      child: const Text('Réinitialiser'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('apply-program-filters'),
                      onPressed: () {
                        setState(() {
                          origin = draftOrigin;
                          generation = draftGeneration;
                          foreverStatus = draftForeverStatus;
                          phase = draftPhase;
                          level = draftLevel;
                          goal = draftGoal;
                          frequency = draftFrequency;
                          mainMovements = draftMainMovements;
                          equipment = draftEquipment;
                          tmRange = draftTmRange;
                          documentation = draftDocumentation;
                          implementation = draftImplementation;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Appliquer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String key,
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: DropdownButtonFormField<T>(
      key: Key(key),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('Tous')),
        ...values.map((v) => DropdownMenuItem(value: v, child: Text(text(v)))),
      ],
      onChanged: onChanged,
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
  });
  final ProgramLibraryEntry entry;
  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      _kindLabel(entry.kind),
      _generation(entry.generation),
      _documentationLabel(entry.documentationStatus),
      if (entry.recommended) 'Recommandé',
      if (!entry.isExecutable) 'Consultation',
    ];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Text(entry.titleFr, key: Key('entry-${entry.id}')),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.map((label) => Chip(label: Text(label))).toList(),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final selected = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) => ProgramLibraryDetailScreen(
                entry: entry,
                mode: mode,
                activePresetId: activePresetId,
                selectedPresetId: selectedPresetId,
              ),
            ),
          );
          if (selected != null && context.mounted) {
            Navigator.pop(context, selected);
          }
        },
      ),
    );
  }
}

class ProgramLibraryDetailScreen extends StatelessWidget {
  const ProgramLibraryDetailScreen({
    required this.entry,
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
    super.key,
  });
  final ProgramLibraryEntry entry;
  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;
  @override
  Widget build(BuildContext context) {
    final canSelect = mode == ProgramLibraryMode.select && entry.isExecutable;
    return Scaffold(
      appBar: AppBar(title: const Text('Fiche détaillée')),
      body: ListView(
        key: const Key('program-detail-list'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(entry.titleFr, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            entry.summaryFr.isEmpty
                ? 'Entrée canonique documentée.'
                : entry.summaryFr,
          ),
          const SizedBox(height: 16),
          Text('Type : ${_kindLabel(entry.kind)}'),
          Text('Origine : ${_generation(entry.origin)}'),
          Text('Génération : ${_generation(entry.generation)}'),
          Text(
            'Niveau : ${entry.level == null ? 'À vérifier' : _levelLabel(entry.level!)}',
          ),
          Text(
            'Fréquence : ${entry.frequencies.isEmpty ? 'À vérifier' : '${entry.frequencies.toList()..sort()} jours'}',
          ),
          Text(
            'Training Max : ${entry.tmRange == null ? 'À vérifier' : '${(entry.tmRange!.minimum * 100).round()}–${(entry.tmRange!.maximum * 100).round()} %'}',
          ),
          Text(
            'Statut documentaire : ${_documentationLabel(entry.documentationStatus)}',
          ),
          Text(
            'Statut d’implémentation : ${entry.implementationStatus == null ? 'Non implémenté' : 'Implémenté'}',
          ),
          if (entry.presetId == activePresetId) const Text('Programme actuel'),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('select-program'),
            onPressed: canSelect && entry.presetId != selectedPresetId
                ? () => Navigator.pop(context, entry.presetId)
                : null,
            child: Text(
              canSelect
                  ? (entry.presetId == selectedPresetId
                        ? 'Programme sélectionné'
                        : 'Choisir ce programme')
                  : 'Consultation uniquement',
            ),
          ),
        ],
      ),
    );
  }
}

String _sortLabel(ProgramLibrarySort value) => switch (value) {
  ProgramLibrarySort.name => 'Nom',
  ProgramLibrarySort.recommendation => 'Recommandation',
  ProgramLibrarySort.level => 'Niveau',
  ProgramLibrarySort.frequency => 'Fréquence',
  ProgramLibrarySort.origin => 'Origine',
  ProgramLibrarySort.documentationMaturity => 'Documentation',
  ProgramLibrarySort.implementationMaturity => 'Implémentation',
  ProgramLibrarySort.complexity => 'Complexité',
};
String _kindLabel(ProgramEntryKind value) => switch (value) {
  ProgramEntryKind.program => 'Programme',
  ProgramEntryKind.component => 'Composant',
  ProgramEntryKind.protocol => 'Protocole',
  ProgramEntryKind.preset => 'Programme exécutable',
  ProgramEntryKind.revision => 'Révision historique',
};
String _generation(MethodGeneration value) => switch (value) {
  MethodGeneration.original => 'Original',
  MethodGeneration.beyond => 'Beyond',
  MethodGeneration.forever => 'Forever',
};
String _levelLabel(ProgramLevel value) => switch (value) {
  ProgramLevel.beginner => 'Débutant',
  ProgramLevel.intermediate => 'Intermédiaire',
  ProgramLevel.advanced => 'Avancé',
};
String _documentationLabel(ProgramValidationStatus value) => switch (value) {
  ProgramValidationStatus.rulesReviewed => 'Règles vérifiées',
  ProgramValidationStatus.indexed => 'Indexé',
  ProgramValidationStatus.needsReview => 'À vérifier',
};
String _foreverStatusLabel(ForeverStatus value) => switch (value) {
  ForeverStatus.current => 'Actuel',
  ForeverStatus.currentWithRestrictions => 'Actuel avec restrictions',
  ForeverStatus.legacy => 'Legacy',
  ForeverStatus.superseded => 'Remplacé',
  ForeverStatus.unknown => 'À vérifier',
};
String _phaseLabel(ProgramPhase value) => switch (value) {
  ProgramPhase.prep => 'Prep',
  ProgramPhase.leader => 'Leader',
  ProgramPhase.anchor => 'Anchor',
  ProgramPhase.transition => 'Transition',
};
String _goalLabel(ProgramGoal value) => switch (value) {
  ProgramGoal.strength => 'Force',
  ProgramGoal.hypertrophy => 'Hypertrophie',
  ProgramGoal.conditioning => 'Conditionnement',
  ProgramGoal.general => 'Général',
};
String _equipmentLabel(ProgramEquipment value) => switch (value) {
  ProgramEquipment.barbell => 'Barre',
  ProgramEquipment.rack => 'Rack',
  ProgramEquipment.bench => 'Banc',
  ProgramEquipment.dumbbells => 'Haltères',
  ProgramEquipment.bodyweight => 'Poids du corps',
};
String _implementationLabel(ProgramImplementationStatus value) =>
    switch (value) {
      ProgramImplementationStatus.experimental => 'Expérimental',
      ProgramImplementationStatus.productionReady => 'Prêt',
    };
