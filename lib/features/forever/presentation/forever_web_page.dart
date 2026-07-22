import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cycle_web/application/cycle_web_contract.dart';
import '../../cycle_web/presentation/cycle_web_page.dart';
import '../../generator_web/design/hybrid_generator_design.dart';
import 'forever_web_contract.dart';

class ForeverWebPage extends StatefulWidget {
  const ForeverWebPage({
    required this.application,
    this.cycleApplication,
    super.key,
  });
  final ForeverWebApplication application;
  final CycleWebApplication? cycleApplication;

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
      final definition = definitions.firstWhere(
        (item) =>
            item.id == stored?.definitionId &&
            item.revision == stored?.definitionRevision,
        orElse: () => definitions.first,
      );
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

  ForeverEditorDraft _initialDraft(ForeverDefinitionItem definition) {
    final selected = <String, String>{};
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        selected[slot.id] = slot.defaultCycleKey;
      }
    }
    return ForeverEditorDraft(
      definitionId: definition.id,
      definitionRevision: definition.revision,
      startDate: DateTime.now(),
      trainingMaxCentiUnits: {
        for (final movement in definition.movementIds) movement: 0,
      },
      selectedCyclesBySlot: selected,
      nodes: _presetNodes(definition, selected),
    );
  }

  ForeverEditorDraft _normalizeDraft(
    ForeverEditorDraft draft,
    ForeverDefinitionItem definition,
  ) {
    final selected = <String, String>{};
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        final value = draft.selectedCyclesBySlot[slot.id];
        selected[slot.id] = slot.allowedCycles.any((c) => c.key == value)
            ? value!
            : slot.defaultCycleKey;
      }
    }
    return draft.copyWith(
      trainingMaxCentiUnits: {
        for (final movement in definition.movementIds)
          movement: draft.trainingMaxCentiUnits[movement] ?? 0,
      },
      selectedCyclesBySlot: selected,
      nodes: draft.nodes.isEmpty
          ? _presetNodes(definition, selected)
          : draft.nodes,
    );
  }

  List<ForeverDraftNode> _presetNodes(
    ForeverDefinitionItem definition,
    Map<String, String> selected,
  ) {
    final nodes = <ForeverDraftNode>[];
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        for (var i = 0; i < slot.repeatCount; i++) {
          nodes.add(
            ForeverDraftNode(
              id: '${slot.id}-${i + 1}',
              role: slot.role,
              cycleKey: selected[slot.id] ?? slot.defaultCycleKey,
            ),
          );
        }
      }
    }
    return nodes;
  }

  Future<void> _change(ForeverEditorDraft draft) async {
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

  Future<void> _selectDefinition(String id) async {
    final definition = _definitions.singleWhere((item) => item.id == id);
    setState(() => _definition = definition);
    await _change(_initialDraft(definition));
  }

  Future<void> _setMode(ForeverWebArchitectureMode mode) async {
    final nodes = mode == ForeverWebArchitectureMode.preset
        ? _presetNodes(_definition!, _draft!.selectedCyclesBySlot)
        : List<ForeverDraftNode>.of(_draft!.nodes);
    await _change(_draft!.copyWith(architectureMode: mode, nodes: nodes));
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
      _draft!.nodes.isNotEmpty &&
      _draft!.trainingMaxCentiUnits.isNotEmpty &&
      _draft!.trainingMaxCentiUnits.values.every((value) => value > 0);

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const HybridGeneratorShell(
        page: HybridGeneratorPage.forever,
        title: 'Forever',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return HybridGeneratorShell(
        page: HybridGeneratorPage.forever,
        title: _t('Générateur Forever', 'Forever generator'),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('Impossible de charger Forever.', 'Unable to load Forever.'),
                key: const Key('forever-error'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _busy = true;
                  });
                  _load();
                },
                child: Text(_t('Réessayer', 'Try again')),
              ),
            ],
          ),
        ),
      );
    }
    return HybridGeneratorShell(
      page: HybridGeneratorPage.forever,
      title: _t('Générateur Forever', 'Forever generator'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= HybridGeneratorTokens.breakpoint;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HybridGeneratorGrid(children: [_weight(), _macrocycle()]),
              const SizedBox(height: HybridGeneratorTokens.gap),
              _globalOptions(),
              const SizedBox(height: HybridGeneratorTokens.gap),
              _plating(),
              const SizedBox(height: HybridGeneratorTokens.gap),
              _cycles(wide),
              const SizedBox(height: HybridGeneratorTokens.gap),
              HybridGeneratorGrid(children: [_timeline(), _output()]),
              if (_generated != null) ...[
                const SizedBox(height: HybridGeneratorTokens.gap),
                _program(),
              ],
            ],
          );
        },
      ),
    );
    /*return Scaffold(
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_t('Impossible de charger Forever.', 'Unable to load Forever.'), key: const Key('forever-error')),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () { setState(() { _error = null; _busy = true; }); _load(); }, child: Text(_t('Réessayer', 'Try again'))),
                ]))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                    sliver: SliverToBoxAdapter(child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 770;
                          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _weight()), const SizedBox(width: 24), Expanded(child: _macrocycle()),
                            ]) else ...[_weight(), const SizedBox(height: 24), _macrocycle()],
                            const SizedBox(height: 24),
                            _globalOptions(),
                            const SizedBox(height: 24),
                            _plating(),
                            const SizedBox(height: 24),
                            _cycles(wide),
                            const SizedBox(height: 24),
                            if (wide) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(child: _timeline()), const SizedBox(width: 24), Expanded(child: _output()),
                            ]) else ...[_timeline(), const SizedBox(height: 24), _output()],
                            if (_generated != null) ...[const SizedBox(height: 24), _program()],
                          ]);
                        }),
                      ),
                    )),
                  ),
                ]),
    );*/
  }

  Widget _section(String title, Widget child, {Key? key}) =>
      HybridGeneratorCard(key: key, title: title, child: child);

  Widget _weight() => _section(
    _t('Poids', 'Weight'),
    Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _t('Training Max initiaux', 'Initial Training Maxes'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 12),
        for (final movement in _definition!.movementIds)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: Key('forever-tm-$movement'),
              initialValue:
                  ((_draft!.trainingMaxCentiUnits[movement] ?? 0) / 100)
                      .toStringAsFixed(0),
              decoration: InputDecoration(
                labelText: _movement(movement),
                suffixText: 'lb',
                helperText: 'Training Max',
              ),
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
                  _change(
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
      ],
    ),
  );

  Widget _macrocycle() => _section(
    _t('Macrocycle', 'Macrocycle'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<ForeverWebArchitectureMode>(
          key: const Key('forever-mode'),
          segments: [
            ButtonSegment(
              value: ForeverWebArchitectureMode.preset,
              label: Text(_t('Programme prédéfini', 'Preset')),
            ),
            ButtonSegment(
              value: ForeverWebArchitectureMode.userDefined,
              label: Text(_t('Personnalisé', 'Custom')),
            ),
          ],
          selected: {_draft!.architectureMode},
          onSelectionChanged: (value) => _setMode(value.first),
        ),
        const SizedBox(height: 16),
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
          onChanged:
              _draft!.architectureMode == ForeverWebArchitectureMode.preset
              ? (value) {
                  if (value != null) _selectDefinition(value);
                }
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          _draft!.architectureMode == ForeverWebArchitectureMode.preset
              ? _t(
                  'Structure canonique publiée. Les nœuds obligatoires sont verrouillés.',
                  'Published canonical structure. Required nodes are locked.',
                )
              : _t(
                  'Architecture libre enregistrée comme userDefined.',
                  'Free architecture recorded as userDefined.',
                ),
        ),
      ],
    ),
  );

  Widget _globalOptions() => _section(
    _t('Options globales', 'Global options'),
    Row(
      children: [
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_t('Date de départ', 'Start date')),
            subtitle: Text(
              MaterialLocalizations.of(
                context,
              ).formatMediumDate(_draft!.startDate),
            ),
          ),
        ),
        IconButton(
          tooltip: _t('Choisir une date', 'Choose date'),
          onPressed: _pickDate,
          icon: const Icon(Icons.edit_calendar),
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _draft!.startDate,
    );
    if (date != null) await _change(_draft!.copyWith(startDate: date));
  }

  Widget _plating() => _section(
    _t('Plaques et barre', 'Plating & barbell'),
    Column(
      children: [
        TextFormField(
          key: const Key('forever-bar-weight'),
          initialValue:
              (((_draft!.equipment['barWeightCentiUnits'] as int?) ?? 4500) /
                      100)
                  .toStringAsFixed(1),
          decoration: InputDecoration(
            labelText: _t('Poids de la barre', 'Bar weight'),
            suffixText: 'lb',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) =>
              _setEquipmentNumber('barWeightCentiUnits', value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('forever-rounding'),
          initialValue:
              (((_draft!.equipment['roundingIncrementCentiUnits'] as int?) ??
                          500) /
                      100)
                  .toStringAsFixed(1),
          decoration: InputDecoration(
            labelText: _t('Arrondi', 'Rounding'),
            suffixText: 'lb',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) =>
              _setEquipmentNumber('roundingIncrementCentiUnits', value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('forever-plates'),
          initialValue:
              ((_draft!.equipment['platesPerSideCentiUnits'] as List?)
                          ?.cast<int>() ??
                      const [4500, 3500, 2500, 1000, 500, 250])
                  .map((value) => (value / 100).toString())
                  .join(', '),
          decoration: InputDecoration(
            labelText: _t('Plaques par côté', 'Plates per side'),
            helperText: _t('Séparées par des virgules', 'Comma separated'),
          ),
          onChanged: (value) {
            final plates = value
                .split(',')
                .map((item) => double.tryParse(item.trim()))
                .whereType<double>()
                .map((item) => (item * 100).round())
                .where((item) => item > 0)
                .toList(growable: false);
            if (plates.isNotEmpty) {
              _change(
                _draft!.copyWith(
                  equipment: {
                    ..._draft!.equipment,
                    'platesPerSideCentiUnits': plates,
                  },
                ),
              );
            }
          },
        ),
      ],
    ),
  );

  void _setEquipmentNumber(String key, String source) {
    final value = double.tryParse(source.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    _change(
      _draft!.copyWith(
        equipment: {..._draft!.equipment, key: (value * 100).round()},
      ),
    );
  }

  Widget _cycles(bool wide) => _section(
    _t('Cycles', 'Cycles'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _draft!.nodes.length; i++) ...[
          _nodeEditor(i),
          if (i != _draft!.nodes.length - 1) const SizedBox(height: 12),
        ],
        if (_draft!.architectureMode ==
            ForeverWebArchitectureMode.userDefined) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _addButton('leader', _t('Ajouter un Leader', 'Add Leader')),
              _addButton('anchor', _t('Ajouter une Ancre', 'Add Anchor')),
              _addButton('deload', _t('Ajouter un protocole', 'Add protocol')),
            ],
          ),
        ],
      ],
    ),
    key: const Key('forever-cycles'),
  );

  Widget _nodeEditor(int index) {
    final node = _draft!.nodes[index];
    final choices = _choicesForRole(node.role);
    final selected = choices.any((c) => c.key == node.cycleKey)
        ? node.cycleKey
        : choices.first.key;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text('C${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _role(node.role),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_draft!.architectureMode ==
                    ForeverWebArchitectureMode.userDefined) ...[
                  IconButton(
                    key: Key('forever-up-$index'),
                    tooltip: _t('Monter', 'Move up'),
                    onPressed: index == 0 ? null : () => _move(index, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: Key('forever-down-$index'),
                    tooltip: _t('Descendre', 'Move down'),
                    onPressed: index == _draft!.nodes.length - 1
                        ? null
                        : () => _move(index, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  PopupMenuButton<String>(
                    tooltip: _t('Actions du cycle', 'Cycle actions'),
                    onSelected: (action) {
                      if (action == 'duplicate') _duplicate(index);
                      if (action == 'copy') _copy(index);
                      if (action == 'remove') _remove(index);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text(_t('Dupliquer', 'Duplicate')),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Text(
                          _t('Copier la configuration', 'Copy configuration'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(_t('Supprimer', 'Remove')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: Key(
                index == 0
                    ? 'forever-slot-${node.id.replaceFirst(RegExp(r'-\d+$'), '')}'
                    : 'forever-node-cycle-$index',
              ),
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('Template · variante', 'Template · variant'),
              ),
              items: choices
                  .map(
                    (c) => DropdownMenuItem(value: c.key, child: Text(c.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _replaceNode(
                    index,
                    node.copyWith(
                      cycleKey: value,
                      clearConfiguration: value != node.cycleKey,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  key: Key('forever-configure-$index'),
                  onPressed: () => _configure(index),
                  icon: const Icon(Icons.tune),
                  label: Text(_t('Configurer', 'Configure')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    node.optionSummary.isEmpty
                        ? _t('Options du catalogue', 'Catalog options')
                        : node.optionSummary.join(' · '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<ForeverCycleChoice> _choicesForRole(String role) {
    final exact = <ForeverCycleChoice>[];
    final all = <ForeverCycleChoice>[];
    for (final phase in _definition!.phases) {
      for (final slot in phase.slots) {
        all.addAll(slot.allowedCycles);
        if (slot.role == role) exact.addAll(slot.allowedCycles);
      }
    }
    final source = exact.isEmpty ? all : exact;
    return {for (final item in source) item.key: item}.values.toList();
  }

  Widget _addButton(String role, String label) => OutlinedButton.icon(
    onPressed: () {
      final choice = _choicesForRole(role).first;
      final nodes = [
        ..._draft!.nodes,
        ForeverDraftNode(
          id: 'user-${DateTime.now().microsecondsSinceEpoch}',
          role: role,
          cycleKey: choice.key,
        ),
      ];
      _change(_draft!.copyWith(nodes: nodes));
    },
    icon: const Icon(Icons.add),
    label: Text(label),
  );

  void _replaceNode(int index, ForeverDraftNode node) {
    final nodes = [..._draft!.nodes];
    nodes[index] = node;
    final slotId = node.id.replaceFirst(RegExp(r'-\d+$'), '');
    final selected = {..._draft!.selectedCyclesBySlot};
    if (selected.containsKey(slotId)) selected[slotId] = node.cycleKey;
    _change(_draft!.copyWith(nodes: nodes, selectedCyclesBySlot: selected));
  }

  void _move(int index, int delta) {
    final nodes = [..._draft!.nodes];
    final node = nodes.removeAt(index);
    nodes.insert(index + delta, node);
    _change(_draft!.copyWith(nodes: nodes));
  }

  void _duplicate(int index) {
    final nodes = [..._draft!.nodes];
    nodes.insert(
      index + 1,
      nodes[index].copyWith(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    _change(_draft!.copyWith(nodes: nodes));
  }

  void _copy(int index) {
    if (index + 1 < _draft!.nodes.length) {
      _replaceNode(
        index + 1,
        _draft!.nodes[index + 1].copyWith(
          cycleKey: _draft!.nodes[index].cycleKey,
          configuration: _draft!.nodes[index].configuration,
        ),
      );
    }
  }

  void _remove(int index) {
    if (_draft!.nodes.length <= 1) return;
    final nodes = [..._draft!.nodes]..removeAt(index);
    _change(_draft!.copyWith(nodes: nodes));
  }

  Future<void> _configure(int index) async {
    final mobile = MediaQuery.sizeOf(context).width < 770;
    final node = _draft!.nodes[index];
    final parts = node.cycleKey.split('/');
    final content = widget.cycleApplication == null
        ? _NodeConfigurationPanel(
            node: node,
            choices: _choicesForRole(node.role),
            french: _fr,
            onApply: (updated) {
              _replaceNode(index, updated);
              Navigator.pop(context);
            },
          )
        : CycleEditorPanel(
            application: widget.cycleApplication!,
            initialState:
                node.configuration ??
                CycleEditorState(
                  templateId: parts.first,
                  variantId: parts.length > 1 ? parts.sublist(1).join('/') : '',
                ),
            onChanged: (configuration) => _replaceNode(
              index,
              node.copyWith(
                cycleKey:
                    '${configuration.templateId}/${configuration.variantId}',
                configuration: configuration,
              ),
            ),
          );
    if (mobile) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(_t('Configurer le cycle', 'Configure cycle')),
            ),
            body: content,
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: content,
          ),
        ),
      );
    }
  }

  Widget _timeline() => _section(
    _t('Timeline', 'Timeline'),
    Column(
      children: [
        for (var i = 0; i < _draft!.nodes.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 15, child: Text('${i + 1}')),
            title: Text(_role(_draft!.nodes[i].role)),
            subtitle: Text(_label(_draft!.nodes[i].cycleKey)),
          ),
      ],
    ),
  );

  Widget _output() => _section(
    _t('Résultat', 'Output'),
    Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_draft!.nodes.length} ${_t('cycles', 'cycles')} · ${_definition!.movementIds.length} ${_t('mouvements', 'movements')}',
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            enabled: _valid,
            label: _t(
              'Générer et sauvegarder le macrocycle',
              'Generate and save macrocycle',
            ),
            excludeSemantics: true,
            child: FilledButton.icon(
              key: const Key('forever-generate'),
              onPressed: _valid ? _generate : null,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_t('Générer et sauvegarder', 'Generate and save')),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.download),
            label: Text(_t('Exporter', 'Export')),
          ),
          if (_generated != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
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
            ),
        ],
      ),
    ),
  );

  Future<void> _export() async {
    if (widget.application is! ForeverWebExportApplication) return;
    final app = widget.application as ForeverWebExportApplication;
    final value = _generated == null
        ? await app.exportDraft(_draft!)
        : await app.exportMacrocycle(_generated!.id);
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Export copié', 'Export copied'))),
      );
    }
  }

  Widget _program() => _section(
    _t('Programme', 'Program'),
    Column(
      children: _generated!.nodes
          .map(
            (node) => Card(
              key: Key('forever-node-${node.index}'),
              child: ExpansionTile(
                initiallyExpanded: node.index == 0,
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
                ],
              ),
            ),
          )
          .toList(),
    ),
  );

  String _movement(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
  String _label(String key) {
    for (final phase in _definition!.phases) {
      for (final slot in phase.slots) {
        for (final choice in slot.allowedCycles) {
          if (choice.key == key) return choice.label;
        }
      }
    }
    return key;
  }

  String _role(String role) => switch (role) {
    'leader' => 'Leader',
    'anchor' => _t('Ancre', 'Anchor'),
    'transition' => 'Transition',
    'deload' => 'Deload',
    'test' => _t('Test TM', 'TM Test'),
    'custom' => _t('Protocole', 'Protocol'),
    _ => role,
  };
}

class _NodeConfigurationPanel extends StatefulWidget {
  const _NodeConfigurationPanel({
    required this.node,
    required this.choices,
    required this.french,
    required this.onApply,
  });
  final ForeverDraftNode node;
  final List<ForeverCycleChoice> choices;
  final bool french;
  final ValueChanged<ForeverDraftNode> onApply;
  @override
  State<_NodeConfigurationPanel> createState() =>
      _NodeConfigurationPanelState();
}

class _NodeConfigurationPanelState extends State<_NodeConfigurationPanel> {
  late String _cycleKey = widget.node.cycleKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.french ? 'Configuration du cycle' : 'Cycle configuration',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _cycleKey,
          decoration: InputDecoration(
            labelText: widget.french
                ? 'Template · variante'
                : 'Template · variant',
          ),
          items: widget.choices
              .map(
                (choice) => DropdownMenuItem(
                  value: choice.key,
                  child: Text(choice.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _cycleKey = value);
          },
        ),
        const SizedBox(height: 16),
        Text(
          widget.french
              ? 'Les options détaillées sont celles déclarées par le catalogue Cycle.'
              : 'Detailed options are provided by the Cycle catalogue.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () =>
              widget.onApply(widget.node.copyWith(cycleKey: _cycleKey)),
          child: Text(widget.french ? 'Appliquer' : 'Apply'),
        ),
      ],
    ),
  );
}
