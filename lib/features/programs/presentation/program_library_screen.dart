import 'package:flutter/material.dart';
import '../domain/program_catalog.dart';
import '../domain/program_identity.dart';

enum ProgramLibraryMode { browse, select }
enum ProgramStatusFilter { current, legacy, all }

class ProgramLibraryScreen extends StatefulWidget {
  const ProgramLibraryScreen({this.mode = ProgramLibraryMode.browse, this.initialOrigin, super.key});
  final ProgramLibraryMode mode;
  final MethodGeneration? initialOrigin;

  @override
  State<ProgramLibraryScreen> createState() => _ProgramLibraryScreenState();
}

class _ProgramLibraryScreenState extends State<ProgramLibraryScreen> {
  ProgramStatusFilter status = ProgramStatusFilter.current;
  MethodGeneration? origin;

  @override
  void initState() { super.initState(); origin = widget.initialOrigin; }

  @override
  Widget build(BuildContext context) {
    const catalog = ProgramCatalog();
    final revisions = ProgramCatalog.revisions.where((revision) {
      final concept = catalog.concept(revision.conceptId);
      final originMatches = origin == null || concept.originGeneration == origin;
      final statusMatches = switch (status) {
        ProgramStatusFilter.current => revision.foreverStatus == ForeverStatus.current || revision.foreverStatus == ForeverStatus.currentWithRestrictions,
        ProgramStatusFilter.legacy => revision.foreverStatus == ForeverStatus.legacy || revision.foreverStatus == ForeverStatus.superseded,
        ProgramStatusFilter.all => true,
      };
      return originMatches && statusMatches;
    }).toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Bibliothèque')),
      body: ListView(
        key: const Key('program-library-list'),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ProgramStatusFilter>(segments: const [
            ButtonSegment(value: ProgramStatusFilter.current, label: Text('Actuels')),
            ButtonSegment(value: ProgramStatusFilter.legacy, label: Text('Legacy')),
            ButtonSegment(value: ProgramStatusFilter.all, label: Text('Tous')),
          ], selected: {status}, onSelectionChanged: (value) => setState(() => status = value.single)),
          const SizedBox(height: 12),
          DropdownButtonFormField<MethodGeneration?>(initialValue: origin, decoration: const InputDecoration(labelText: 'Origine'), items: const [
            DropdownMenuItem(value: null, child: Text('Toutes')),
            DropdownMenuItem(value: MethodGeneration.original, child: Text('Original')),
            DropdownMenuItem(value: MethodGeneration.beyond, child: Text('Beyond')),
            DropdownMenuItem(value: MethodGeneration.forever, child: Text('Forever')),
          ], onChanged: (value) => setState(() => origin = value)),
          const SizedBox(height: 12),
          for (final revision in revisions) _RevisionCard(revision: revision, concept: catalog.concept(revision.conceptId)),
          if (revisions.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aucune révision dans ce filtre.')),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.revision, required this.concept});
  final ProgramRevision revision;
  final ProgramConcept concept;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    title: Text(concept.id.replaceAll('-', ' ').toUpperCase()),
    subtitle: Text('Origine : ${concept.originGeneration?.name ?? 'À vérifier'}\nRévision : ${revision.generation.name}\nStatut : ${revision.foreverStatus.name}\nDocumentation : ${revision.documentationStatus.name}'),
    isThreeLine: true,
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgramDetailScreen(concept: concept))),
  ));
}

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({required this.concept, super.key});
  final ProgramConcept concept;
  @override
  Widget build(BuildContext context) {
    final revisions = ProgramCatalog.revisions.where((item) => item.conceptId == concept.id);
    return Scaffold(appBar: AppBar(title: Text(concept.id.replaceAll('-', ' '))), body: ListView(key: const Key('program-detail-list'), padding: const EdgeInsets.all(20), children: [
      Text('Origine : ${concept.originGeneration?.name ?? 'À vérifier'}'),
      Text('Type : ${concept.type.name}'),
      Text('Documentation : ${concept.documentationStatus.name}'),
      const SizedBox(height: 20),
      const Text('Historique des révisions'),
      for (final revision in revisions) ListTile(title: Text(revision.generation.name), subtitle: Text('${revision.id} · ${revision.foreverStatus.name}')),
    ]));
  }
}
