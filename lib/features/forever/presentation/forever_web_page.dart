import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'forever_web_contract.dart';

class ForeverWebPage extends StatefulWidget {
  const ForeverWebPage({required this.application, super.key});
  final ForeverWebApplication application;

  @override
  State<ForeverWebPage> createState() => _ForeverWebPageState();
}

class _ForeverWebPageState extends State<ForeverWebPage> {
  List<ForeverDefinitionItem> _definitions = const [];
  ForeverDefinitionItem? _definition;
  ForeverEditorDraft? _draft;
  GeneratedMacrocycleView? _generated;
  Object? _error;
  bool _busy = true;

  bool get _fr => Localizations.localeOf(context).languageCode == 'fr';
  String _t(String fr, String en) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final definitions = await widget.application.loadDefinitions();
      if (definitions.isEmpty) throw StateError('Forever catalogue is empty');
      final stored = await widget.application.loadDraft();
      final definition = definitions.cast<ForeverDefinitionItem?>().firstWhere(
        (item) =>
            item?.id == stored?.definitionId &&
            item?.revision == stored?.definitionRevision,
        orElse: () => definitions.first,
      )!;
      final draft = stored == null || stored.definitionId != definition.id
          ? _initialDraft(definition)
          : _normalizeDraft(stored, definition);
      final saved = await widget.application.loadSavedMacrocycle();
      if (!mounted) return;
      setState(() {
        _definitions = definitions;
        _definition = definition;
        _draft = draft;
        _generated = saved;
        _busy = false;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  ForeverEditorDraft _initialDraft(ForeverDefinitionItem definition) =>
      ForeverEditorDraft(
        definitionId: definition.id,
        definitionRevision: definition.revision,
        startDate: DateTime.now(),
        trainingMaxCentiUnits: {
          for (final movement in definition.movementIds) movement: 0,
        },
        selectedCyclesBySlot: {
          for (final phase in definition.phases)
            for (final slot in phase.slots) slot.id: slot.defaultCycleKey,
        },
      );

  ForeverEditorDraft _normalizeDraft(
    ForeverEditorDraft draft,
    ForeverDefinitionItem definition,
  ) => draft.copyWith(
    trainingMaxCentiUnits: {
      for (final movement in definition.movementIds)
        movement: draft.trainingMaxCentiUnits[movement] ?? 0,
    },
    selectedCyclesBySlot: {
      for (final phase in definition.phases)
        for (final slot in phase.slots)
          slot.id:
              slot.allowedCycles.any(
                (cycle) => cycle.key == draft.selectedCyclesBySlot[slot.id],
              )
              ? draft.selectedCyclesBySlot[slot.id]!
              : slot.defaultCycleKey,
    },
  );

  Future<void> _selectDefinition(String id) async {
    final definition = _definitions.singleWhere((item) => item.id == id);
    final draft = _initialDraft(definition);
    setState(() {
      _definition = definition;
      _draft = draft;
      _generated = null;
    });
    await widget.application.saveDraft(draft);
  }

  Future<void> _updateDraft(ForeverEditorDraft draft) async {
    setState(() {
      _draft = draft;
      _generated = null;
    });
    try {
      await widget.application.saveDraft(draft);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.application.saveDraft(_draft!);
      final generated = await widget.application.generateSaveAndReload(_draft!);
      if (mounted) {
        setState(() {
          _generated = generated;
          _busy = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  bool get _valid =>
      _draft != null &&
      _draft!.trainingMaxCentiUnits.isNotEmpty &&
      _draft!.trainingMaxCentiUnits.values.every((value) => value > 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Générateur Forever', 'Forever generator')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/cycle'),
            child: Text(_t('Cycles', 'Cycles')),
          ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _t('Impossible de charger Forever.', 'Unable to load Forever.'),
                key: const Key('forever-error'),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final editor = _editor();
                final preview = _preview();
                return constraints.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: editor),
                          Expanded(child: preview),
                        ],
                      )
                    : ListView(children: [editor, preview]);
              },
            ),
    );
  }

  Widget _editor() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('Configuration', 'Configuration'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('forever-definition'),
          initialValue: _definition!.id,
          decoration: InputDecoration(
            labelText: _t('Programme publié', 'Published program'),
          ),
          items: _definitions
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(_fr ? item.labelFr : item.labelEn),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) _selectDefinition(value);
          },
        ),
        const SizedBox(height: 20),
        Text(
          _t('Training Max initiaux', 'Initial Training Maxes'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ..._definition!.movementIds.map(
          (movement) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              key: Key('forever-tm-$movement'),
              initialValue:
                  ((_draft!.trainingMaxCentiUnits[movement] ?? 0) / 100)
                      .toStringAsFixed(0),
              decoration: InputDecoration(labelText: '$movement (lb)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,4}([.,]\d{0,2})?'),
                ),
              ],
              onChanged: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed != null) {
                  _updateDraft(
                    _draft!.copyWith(
                      trainingMaxCentiUnits: {
                        ..._draft!.trainingMaxCentiUnits,
                        movement: (parsed * 100).round(),
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t('Choix des cycles', 'Cycle choices'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final phase in _definition!.phases)
          for (final slot in phase.slots)
            if (slot.allowedCycles.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  key: Key('forever-slot-${slot.id}'),
                  initialValue: _draft!.selectedCyclesBySlot[slot.id],
                  decoration: InputDecoration(
                    labelText: '${_role(slot.role)} · ${slot.id}',
                  ),
                  items: slot.allowedCycles
                      .map(
                        (cycle) => DropdownMenuItem(
                          value: cycle.key,
                          child: Text(cycle.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _updateDraft(
                        _draft!.copyWith(
                          selectedCyclesBySlot: {
                            ..._draft!.selectedCyclesBySlot,
                            slot.id: value,
                          },
                        ),
                      );
                    }
                  },
                ),
              ),
        const SizedBox(height: 20),
        Semantics(
          button: true,
          enabled: _valid,
          excludeSemantics: true,
          label: _t(
            'Générer et sauvegarder le macrocycle',
            'Generate and save macrocycle',
          ),
          child: FilledButton.icon(
            key: const Key('forever-generate'),
            onPressed: _valid ? _generate : null,
            icon: const Icon(Icons.auto_awesome),
            label: Text(_t('Générer et sauvegarder', 'Generate and save')),
          ),
        ),
      ],
    ),
  );

  Widget _preview() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('Timeline', 'Timeline'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (_generated == null)
          ..._timelineCards()
        else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _generated!.wasReloaded
                  ? _t(
                      'Macrocycle sauvegardé et relu',
                      'Macrocycle saved and reloaded',
                    )
                  : _t('Macrocycle chargé', 'Macrocycle loaded'),
              key: const Key('forever-saved-status'),
            ),
          ),
          const SizedBox(height: 8),
          ..._generated!.nodes.map(_nodeCard),
        ],
      ],
    ),
  );

  Iterable<Widget> _timelineCards() sync* {
    var index = 0;
    for (final phase in _definition!.phases) {
      for (final slot in phase.slots) {
        for (var repeat = 0; repeat < slot.repeatCount; repeat++) {
          index++;
          final key =
              _draft!.selectedCyclesBySlot[slot.id] ?? slot.defaultCycleKey;
          final label = slot.allowedCycles
              .singleWhere((cycle) => cycle.key == key)
              .label;
          yield Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('$index')),
              title: Text(_role(slot.role)),
              subtitle: Text(label),
              trailing: slot.repeatCount > 1
                  ? Text('${repeat + 1}/${slot.repeatCount}')
                  : null,
            ),
          );
        }
      }
    }
  }

  Widget _nodeCard(GeneratedMacrocycleNodeView node) => Card(
    key: Key('forever-node-${node.index}'),
    child: ExpansionTile(
      leading: CircleAvatar(child: Text('${node.index + 1}')),
      title: Text('${_role(node.role)} · ${node.cycleLabel}'),
      subtitle: Text(
        '${MaterialLocalizations.of(context).formatShortDate(node.startDate)} – ${MaterialLocalizations.of(context).formatShortDate(node.endDate)}',
      ),
      children: [
        for (final week in node.weeks)
          ListTile(
            title: Text('${_t('Semaine', 'Week')} ${week.number}'),
            subtitle: Text(week.sessions.join(' · ')),
          ),
        TextButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, '/cycle', arguments: node),
          icon: const Icon(Icons.open_in_new),
          label: Text(_t('Ouvrir le cycle', 'Open cycle')),
        ),
      ],
    ),
  );

  String _role(String role) => switch (role) {
    'leader' => 'Leader',
    'anchor' => _t('Ancre', 'Anchor'),
    'transition' => _t('Transition', 'Transition'),
    'deload' => 'Deload',
    'test' => _t('Test TM', 'TM Test'),
    _ => role,
  };
}
