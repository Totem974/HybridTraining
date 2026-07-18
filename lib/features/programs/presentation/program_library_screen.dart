import 'package:flutter/material.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';

enum ProgramLibraryMode { browse, select }

enum ProgramStatusFilter { current, legacy, all }

class ProgramLibraryScreen extends StatefulWidget {
  const ProgramLibraryScreen({
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
    this.initialOrigin,
    this.initialStatus = ProgramStatusFilter.current,
    super.key,
  });

  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;
  final MethodGeneration? initialOrigin;
  final ProgramStatusFilter initialStatus;

  @override
  State<ProgramLibraryScreen> createState() => _ProgramLibraryScreenState();
}

class _ProgramLibraryScreenState extends State<ProgramLibraryScreen> {
  ProgramStatusFilter status = ProgramStatusFilter.current;
  MethodGeneration? origin;

  @override
  void initState() {
    super.initState();
    origin = widget.initialOrigin;
    status = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    const catalog = ProgramCatalog();
    final concepts = catalog.concepts
        .where((concept) {
          if (origin != null && concept.originGeneration != origin) {
            return false;
          }
          final revisions = catalog.revisionsFor(concept.id);
          return switch (status) {
            ProgramStatusFilter.current => revisions.any(
              (item) =>
                  item.foreverStatus == ForeverStatus.current ||
                  item.foreverStatus == ForeverStatus.currentWithRestrictions,
            ),
            ProgramStatusFilter.legacy => revisions.any(
              (item) =>
                  item.foreverStatus == ForeverStatus.legacy ||
                  item.foreverStatus == ForeverStatus.superseded,
            ),
            ProgramStatusFilter.all => true,
          };
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: Text(strings.library)),
      body: ListView(
        key: const Key('program-library-list'),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ProgramStatusFilter>(
            segments: [
              ButtonSegment(
                value: ProgramStatusFilter.current,
                label: Text(strings.currentFilter),
              ),
              ButtonSegment(
                value: ProgramStatusFilter.legacy,
                label: Text(strings.legacyFilter),
              ),
              ButtonSegment(
                value: ProgramStatusFilter.all,
                label: Text(strings.allFilter),
              ),
            ],
            selected: {status},
            onSelectionChanged: (value) =>
                setState(() => status = value.single),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MethodGeneration?>(
            initialValue: origin,
            decoration: InputDecoration(labelText: strings.origin),
            items: [
              DropdownMenuItem(value: null, child: Text(strings.allOrigins)),
              DropdownMenuItem(
                value: MethodGeneration.original,
                child: Text(strings.originalGeneration),
              ),
              DropdownMenuItem(
                value: MethodGeneration.beyond,
                child: Text(strings.beyondGeneration),
              ),
              DropdownMenuItem(
                value: MethodGeneration.forever,
                child: Text(strings.foreverGeneration),
              ),
            ],
            onChanged: (value) => setState(() => origin = value),
          ),
          const SizedBox(height: 12),
          for (final concept in concepts)
            _ConceptCard(
              concept: concept,
              catalog: catalog,
              mode: widget.mode,
              activePresetId: widget.activePresetId,
              selectedPresetId: widget.selectedPresetId,
            ),
          if (concepts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                strings.noProgramsForFilter,
                key: const Key('empty-program-filter'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({
    required this.concept,
    required this.catalog,
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
  });
  final ProgramConcept concept;
  final ProgramCatalog catalog;
  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    final revisions = catalog.revisionsFor(concept.id);
    final relevant =
        revisions
            .where(
              (item) =>
                  item.foreverStatus == ForeverStatus.current ||
                  item.foreverStatus == ForeverStatus.currentWithRestrictions,
            )
            .firstOrNull ??
        revisions.lastOrNull;
    final preset = catalog.presetForConcept(concept.id);
    final badges = <String>[
      if (preset?.persistentPresetId == activePresetId) strings.currentProgram,
      if (preset?.persistentPresetId == selectedPresetId)
        strings.selectedProgramBadge,
      if (preset?.recommended ?? false) strings.recommended,
    ];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          strings.programLabel(concept.titleKey),
          key: Key('concept-${concept.id}'),
        ),
        subtitle: Text(
          [
            '${strings.origin}: ${strings.generationLabel(concept.originGeneration?.name)}',
            '${strings.revision}: ${relevant == null ? strings.toReview : strings.generationLabel(relevant.generation.name)}',
            '${strings.foreverState}: ${strings.foreverStatusLabel(relevant?.foreverStatus.name)}',
            '${strings.validationStatus}: ${strings.documentationStatusLabel(relevant?.documentationStatus.name ?? concept.documentationStatus.name)}',
            '${strings.productAvailability}: ${strings.availabilityLabel(catalog.availabilityFor(concept.id).name)}',
            if (badges.isNotEmpty) badges.join(' · '),
          ].join('\n'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final selected = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => ProgramDetailScreen(
                concept: concept,
                mode: mode,
                activePresetId: activePresetId,
                selectedPresetId: selectedPresetId,
              ),
            ),
          );
          if (selected != null && context.mounted) {
            Navigator.of(context).pop(selected);
          }
        },
      ),
    );
  }
}

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({
    required this.concept,
    required this.mode,
    this.activePresetId,
    this.selectedPresetId,
    super.key,
  });
  final ProgramConcept concept;
  final ProgramLibraryMode mode;
  final String? activePresetId;
  final String? selectedPresetId;

  @override
  Widget build(BuildContext context) {
    const strings = AppStrings();
    const catalog = ProgramCatalog();
    final revisions = catalog.revisionsFor(concept.id);
    final preset = catalog.presetForConcept(concept.id);
    final availability = catalog.availabilityFor(concept.id);
    final canSelect =
        mode == ProgramLibraryMode.select &&
        availability == ProductAvailability.available &&
        preset != null;
    final isSelected = preset?.persistentPresetId == selectedPresetId;
    final isActive = preset?.persistentPresetId == activePresetId;
    final buttonText = isSelected
        ? strings.programSelected
        : isActive && mode == ProgramLibraryMode.browse
        ? strings.currentProgram
        : canSelect
        ? strings.chooseProgram
        : strings.availabilityAction(
            availability.name,
            concept.documentationStatus.name,
          );
    return Scaffold(
      appBar: AppBar(title: Text(strings.programDetails)),
      body: ListView(
        key: const Key('program-detail-list'),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.programLabel(concept.titleKey),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${strings.origin}: ${strings.generationLabel(concept.originGeneration?.name)}',
          ),
          Text(
            '${strings.conceptType}: ${strings.conceptTypeLabel(concept.type.name)}',
          ),
          Text(
            '${strings.productAvailability}: ${strings.availabilityLabel(availability.name)}',
          ),
          const SizedBox(height: 20),
          Text(
            strings.revisionHistory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final revision in revisions)
            ListTile(
              title: Text(strings.generationLabel(revision.generation.name)),
              subtitle: Text(
                '${strings.foreverState}: ${strings.foreverStatusLabel(revision.foreverStatus.name)}\n${strings.validationStatus}: ${strings.documentationStatusLabel(revision.documentationStatus.name)}${_references(strings, revision.references)}',
              ),
            ),
          if (revisions.isEmpty) Text(strings.rulesNeedReview),
          if (preset != null) ...[
            const SizedBox(height: 20),
            Text(
              strings.presetDetails,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${strings.persistentPreset}: ${preset.persistentPresetId}'),
            Text(
              '${strings.rulesGeneration}: ${strings.generationLabel(preset.rulesetGeneration.name)}',
            ),
            Text(
              '${strings.mainWork}: ${strings.programLabel(catalog.concept(catalog.revision(preset.mainRevisionId).conceptId).titleKey)}',
            ),
            if (preset.supplementalRevisionId != null)
              Text(
                '${strings.supplementalWork}: ${strings.programLabel(catalog.concept(catalog.revision(preset.supplementalRevisionId!).conceptId).titleKey)}',
              ),
            Text('${strings.trainingMax}: 90 %'),
            Text(
              '${strings.supportedFrequencies}: ${preset.supportedFrequencies.toList()..sort()}',
            ),
            Text(
              '${strings.recommendedFrequency}: ${preset.recommendedFrequency}',
            ),
            Text('${strings.version}: ${preset.version}'),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('select-program'),
            onPressed: canSelect && !isSelected
                ? () => Navigator.of(context).pop(preset.persistentPresetId)
                : null,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  String _references(
    AppStrings strings,
    List<ProgramDocumentReference> references,
  ) => references.isEmpty
      ? ''
      : '\n${strings.documentarySource}: ${references.map((item) => '${item.title}, ${item.bookPages} / ${item.pdfPages}').join('; ')}';
}
