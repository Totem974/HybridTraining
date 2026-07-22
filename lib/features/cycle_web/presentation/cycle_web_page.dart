import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_option_schema.dart';
import '../../training_catalog/domain/catalog_index.dart';
import '../../generator_web/design/hybrid_generator_design.dart';
import '../application/cycle_option_condition_evaluator.dart';
import '../application/cycle_web_contract.dart';
import 'blocks/additional_options/additional_options_block.dart';
import 'blocks/output/cycle_output_block.dart';
import 'blocks/plating/cycle_plating_block.dart';
import 'blocks/scheduling/cycle_scheduling_block.dart';
import 'blocks/template/cycle_template_block.dart';
import 'blocks/weight/cycle_weight_block.dart';
import 'program/cycle_program.dart';

class CycleWebPage extends StatefulWidget {
  const CycleWebPage({
    required this.application,
    this.foreverRoute = '/forever',
    this.initialState,
    this.onStateChanged,
    this.embedded = false,
    super.key,
  });

  final CycleWebApplication application;
  final String foreverRoute;
  final CycleEditorState? initialState;
  final ValueChanged<CycleEditorState>? onStateChanged;
  final bool embedded;

  @override
  State<CycleWebPage> createState() => _CycleWebPageState();
}

class _CycleWebPageState extends State<CycleWebPage> {
  CycleCatalogIndex? _index;
  CycleEditorSchema? _schema;
  CycleEditorState? _state;
  GeneratedCycleView? _generated;
  List<String> _movementIds = const [];
  Object? _error;
  bool _busy = true;

  bool get _isFrench => Localizations.localeOf(context).languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final index = await widget.application.loadIndex();
      if (index.templates.isEmpty) {
        throw StateError('The Cycle catalogue is empty.');
      }
      final draft = widget.initialState ?? await widget.application.loadDraft();
      final selection = _validSelection(index, draft);
      final schema = await widget.application.loadEditorSchema(
        templateId: selection.templateId,
        variantId: selection.variantId,
      );
      final movementIds = await widget.application.loadMovementIds(
        templateId: selection.templateId,
        variantId: selection.variantId,
      );
      final sessionIds = await widget.application.loadSessionIds(
        templateId: selection.templateId,
        variantId: selection.variantId,
      );
      final values = {
        for (final option in schema.options)
          option.id: _initialOptionValue(
            option,
            movementIds,
            draft?.values[option.id],
          ),
      };
      if (!mounted) return;
      setState(() {
        _index = index;
        _schema = schema;
        _movementIds = movementIds;
        _state = CycleEditorState(
          templateId: selection.templateId,
          variantId: selection.variantId,
          values: values,
          startDate: draft?.startDate ?? DateTime.now(),
          trainingDays: _validSchedule(draft, sessionIds)
              ? draft!.trainingDays
              : _defaultTrainingDays(sessionIds.length),
          sessionOrder: _validSchedule(draft, sessionIds)
              ? draft!.sessionOrder
              : sessionIds,
          maxInputs: draft?.maxInputs ?? const {},
          globalTrainingMaxRatioBasisPoints:
              draft?.globalTrainingMaxRatioBasisPoints ?? 9000,
          trainingMaxRatioByMovementBasisPoints:
              draft?.trainingMaxRatioByMovementBasisPoints ?? const {},
          unit: draft?.unit ?? WeightUnit.kg,
          roundingIncrementCentiUnits:
              draft?.roundingIncrementCentiUnits ?? 250,
          barWeightCentiUnits: draft?.barWeightCentiUnits ?? 2000,
          platesPerSideCentiUnits: draft?.platesPerSideCentiUnits ?? const [],
          programTitle: draft?.programTitle ?? '',
          showPlating: draft?.showPlating ?? true,
          cycleId:
              draft?.cycleId ??
              'cycle-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        );
        _busy = false;
      });
      widget.onStateChanged?.call(_state!);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
    }
  }

  CycleEditorState _validSelection(
    CycleCatalogIndex index,
    CycleEditorState? draft,
  ) {
    if (draft != null) {
      for (final template in index.templates) {
        if (template.id == draft.templateId &&
            template.variantIds.contains(draft.variantId)) {
          return draft;
        }
      }
    }
    final template = index.templates.first;
    if (template.variantIds.isEmpty) {
      throw StateError('A Cycle template has no variants.');
    }
    return CycleEditorState(
      templateId: template.id,
      variantId: template.variantIds.first,
    );
  }

  Future<void> _selectTemplate(String templateId) async {
    final template = _index!.templates.singleWhere(
      (item) => item.id == templateId,
    );
    await _select(templateId, template.variantIds.first);
  }

  Future<void> _selectVariant(String variantId) async =>
      _select(_state!.templateId, variantId);

  Future<void> _select(String templateId, String variantId) async {
    setState(() {
      _busy = true;
      _error = null;
      _generated = null;
    });
    try {
      final schema = await widget.application.loadEditorSchema(
        templateId: templateId,
        variantId: variantId,
      );
      final movementIds = await widget.application.loadMovementIds(
        templateId: templateId,
        variantId: variantId,
      );
      final sessionIds = await widget.application.loadSessionIds(
        templateId: templateId,
        variantId: variantId,
      );
      final state = CycleEditorState(
        templateId: templateId,
        variantId: variantId,
        values: {
          for (final option in schema.options)
            option.id: _initialOptionValue(option, movementIds, null),
        },
        startDate: _state?.startDate ?? DateTime.now(),
        trainingDays: _defaultTrainingDays(sessionIds.length),
        sessionOrder: sessionIds,
        unit: _state?.unit ?? WeightUnit.kg,
        globalTrainingMaxRatioBasisPoints:
            _state?.globalTrainingMaxRatioBasisPoints ?? 9000,
        roundingIncrementCentiUnits: _state?.roundingIncrementCentiUnits ?? 250,
        barWeightCentiUnits: _state?.barWeightCentiUnits ?? 2000,
        platesPerSideCentiUnits: _state?.platesPerSideCentiUnits ?? const [],
        programTitle: _state?.programTitle ?? '',
        showPlating: _state?.showPlating ?? true,
        cycleId: 'cycle-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      );
      await widget.application.saveDraft(state);
      if (!mounted) return;
      setState(() {
        _schema = schema;
        _movementIds = movementIds;
        _state = state;
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

  bool _validSchedule(CycleEditorState? draft, List<String> sessionIds) {
    if (draft == null || draft.trainingDays.length != sessionIds.length) {
      return false;
    }
    return draft.trainingDays.toSet().length == sessionIds.length &&
        draft.trainingDays.every((day) => day >= 1 && day <= 7) &&
        draft.sessionOrder.length == sessionIds.length &&
        draft.sessionOrder.toSet().containsAll(sessionIds);
  }

  List<int> _defaultTrainingDays(int count) {
    const schedules = <int, List<int>>{
      1: [1],
      2: [1, 4],
      3: [1, 3, 5],
      4: [1, 2, 4, 5],
      5: [1, 2, 3, 5, 6],
      6: [1, 2, 3, 4, 5, 6],
      7: [1, 2, 3, 4, 5, 6, 7],
    };
    return schedules[count] ??
        (throw StateError('A Cycle cannot contain $count weekly sessions.'));
  }

  Object _initialOptionValue(
    CycleOptionDefinition option,
    List<String> movementIds,
    Object? savedValue,
  ) {
    final value = savedValue ?? option.defaultValue;
    if (option.scope != CycleOptionScope.perMovement) return value;
    if (value is Map<Object?, Object?>) return value;
    return {for (final movementId in movementIds) movementId: value};
  }

  Future<void> _setOption(String id, Object value) async {
    final state = _state!.copyWith(values: {..._state!.values, id: value});
    await _setState(state);
  }

  Future<void> _setState(CycleEditorState state) async {
    setState(() {
      _state = state;
      _generated = null;
    });
    widget.onStateChanged?.call(state);
    try {
      await widget.application.saveDraft(state);
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
      await widget.application.saveDraft(_state!);
      final generated = await widget.application.generate(_state!);
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

  Future<void> _export() async {
    if (widget.application is! CycleWebExportApplication) return;
    final application = widget.application as CycleWebExportApplication;
    final source = _generated == null
        ? await application.exportCycleDraft(_state!)
        : await application.exportGeneratedCycle(_generated!);
    await Clipboard.setData(ClipboardData(text: source));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFrench ? 'Export copié.' : 'Export copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.embedded
      ? SingleChildScrollView(
          key: const Key('cycle-editor-panel'),
          padding: const EdgeInsets.all(HybridGeneratorTokens.mobilePadding),
          child: _body(),
        )
      : KeyedSubtree(
          key: const Key('cycle-web-page'),
          child: HybridGeneratorShell(
            page: HybridGeneratorPage.cycle,
            title: _isFrench ? 'Générateur de cycle' : 'Cycle generator',
            onNavigate: (page) {
              if (page == HybridGeneratorPage.forever) {
                Navigator.of(context).pushReplacementNamed(widget.foreverRoute);
              }
            },
            child: _body(),
          ),
        );

  Widget _body() {
    if (_busy && _state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state == null || _index == null || _schema == null) {
      return _ErrorPanel(error: _error, onRetry: _load, isFrench: _isFrench);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 770;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _responsivePair(_newWeightCard(), _newSelectionCard(), desktop),
            const SizedBox(height: 24),
            _newOptionsCard(),
            const SizedBox(height: 24),
            _newPlatingCard(),
            const SizedBox(height: 24),
            if (widget.embedded)
              _newSchedulingCard()
            else
              _responsivePair(_newSchedulingCard(), _newOutputCard(), desktop),
            if (!widget.embedded) ...[
              const SizedBox(height: 24),
              _sectionCard(
                title: _isFrench ? 'PROGRAMME' : 'PROGRAM',
                child: _generated == null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _isFrench
                              ? 'Renseignez vos charges : le programme apparaîtra ici.'
                              : 'Enter your weights and the program will appear here.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: HybridGeneratorTokens.textMuted,
                          ),
                        ),
                      )
                    : CycleProgram(
                        view: _generated!,
                        labelFor: _humanize,
                        showPlating: _state!.showPlating,
                        isFrench: _isFrench,
                      ),
              ),
            ],
          ],
        );
        return content;
      },
    );
  }

  Widget _responsivePair(Widget left, Widget right, bool desktop) =>
      HybridGeneratorGrid(children: [left, right]);

  Widget _sectionCard({required String title, required Widget child}) =>
      HybridGeneratorCard(title: title, child: child);

  Widget _newWeightCard() => HybridGeneratorCard(
    title: _isFrench ? 'CHARGES' : 'WEIGHT',
    child: CycleWeightBlock(
      state: _state!,
      movementIds: _movementIds,
      onMaxInputKindChanged: (kind) {
        final inputs = <String, CycleMovementMaxInput>{
          for (final movement in _movementIds)
            movement: CycleMovementMaxInput(
              kind: kind,
              weightCentiUnits:
                  _state!.maxInputs[movement]?.weightCentiUnits ?? 0,
              repetitions: kind == CycleMaxInputKind.repMax
                  ? (_state!.maxInputs[movement]?.repetitions ?? 1)
                  : null,
            ),
        };
        _setState(_state!.copyWith(maxInputs: inputs));
      },
      onMovementInputChanged: _setMovementInput,
      onGlobalTrainingMaxRatioChanged: (ratio) =>
          _setState(_state!.copyWith(globalTrainingMaxRatioBasisPoints: ratio)),
      onUnitChanged: (unit) => _setState(_state!.copyWith(unit: unit)),
    ),
  );

  Widget _newSelectionCard() => CycleTemplateBlock(
    index: _index!,
    state: _state!,
    enabled: !_busy,
    isFrench: _isFrench,
    templateLabelBuilder: _templateLabel,
    variantLabelBuilder: _humanize,
    onTemplateSelected: _selectTemplate,
    onVariantSelected: _selectVariant,
    options: _templateOptions(),
  );

  Widget? _templateOptions() {
    final options = _visibleOptions(
      CycleOptionPresentationGroup.template,
    ).toList();
    if (options.isEmpty) return null;
    return Column(children: options.map(_optionField).toList());
  }

  Iterable<CycleOptionDefinition> _visibleOptions(
    CycleOptionPresentationGroup group,
  ) => _schema!.options.where(
    (option) =>
        option.presentationGroup == group &&
        CycleOptionConditionEvaluator.evaluate(
          option.visibleWhen,
          _state!.values,
        ),
  );

  Widget _newOptionsCard() {
    AdditionalOptionGroup? group(
      CycleOptionPresentationGroup kind,
      String label,
    ) {
      final options = _visibleOptions(kind).toList();
      if (options.isEmpty) return null;
      return AdditionalOptionGroup(
        id: kind.name,
        label: label,
        children: options.map(_optionField).toList(),
      );
    }

    final primary = [
      group(CycleOptionPresentationGroup.warmup, 'WARM-UP'),
      group(CycleOptionPresentationGroup.joker, 'JOKER SETS'),
      group(CycleOptionPresentationGroup.deload, 'DELOAD'),
    ].whereType<AdditionalOptionGroup>().toList();
    final secondary = [
      group(
        CycleOptionPresentationGroup.supplemental,
        _isFrench ? 'SUPPLÉMENTAIRE' : 'SUPPLEMENTAL',
      ),
      group(CycleOptionPresentationGroup.assistance, 'ASSISTANCE'),
      group(CycleOptionPresentationGroup.conditioning, 'CONDITIONING'),
    ].whereType<AdditionalOptionGroup>().toList();
    return AdditionalOptionsBlock(
      title: _isFrench ? 'OPTIONS SUPPLÉMENTAIRES' : 'ADDITIONAL OPTIONS',
      primaryGroups: primary,
      secondaryGroups: secondary,
      emptyLabel: _isFrench
          ? 'Aucune option supplémentaire pour ce modèle.'
          : 'No additional options for this template.',
    );
  }

  Widget _newPlatingCard() {
    final maximum =
        _state!.barWeightCentiUnits +
        2 * _state!.platesPerSideCentiUnits.fold<int>(0, (a, b) => a + b);
    return CyclePlatingBlock(
      title: _isFrench ? 'PLAQUES ET BARRE' : 'PLATING & BARBELL',
      denominations: [
        for (final plate in _plateChoices)
          CyclePlateDenominationView(
            centiUnits: plate,
            label: '${_formatWeight(plate)} ${_state!.unit.name}',
            count: _plateCount(plate),
          ),
      ],
      barWeightCaption: _isFrench ? 'Poids de la barre' : 'Barbell weight',
      barWeightLabel:
          '${_formatWeight(_state!.barWeightCentiUnits)} ${_state!.unit.name}',
      maximumWeightCaption: _isFrench
          ? 'Poids total maximal'
          : 'Maximum total weight',
      maximumWeightLabel: '${_formatWeight(maximum)} ${_state!.unit.name}',
      onCountChanged: (plate, count) {
        final current = _plateCount(plate);
        _changePlateCount(plate, count - current);
      },
    );
  }

  Widget _newSchedulingCard() {
    final order = _state!.sessionOrder;
    return CycleSchedulingBlock(
      viewModel: CycleSchedulingViewModel(
        frequency: order.length,
        allowedFrequencies: [
          CycleFrequencyView(value: order.length, label: '${order.length}'),
        ],
        sessions: [
          for (final session in order)
            CycleSessionTokenView(key: session, label: _humanize(session)),
        ],
        startDate: _state!.startDate,
        canMoveSessionLeft: order.skip(1).toSet(),
        canMoveSessionRight: order.take(order.length - 1).toSet(),
      ),
      title: _isFrench ? 'PLANIFICATION' : 'SCHEDULING',
      frequencyLabel: _isFrench ? 'Jours par semaine' : 'Days a week',
      sessionOrderLabel: _isFrench ? 'Ordre des séances' : 'Lifts order',
      startDateLabel: _isFrench ? 'Date de début' : 'Start date',
      onStartDateChanged: (date) =>
          _setState(_state!.copyWith(startDate: date)),
      onMoveSessionLeft: (id) => _moveSession(id, -1),
      onMoveSessionRight: (id) => _moveSession(id, 1),
    );
  }

  void _moveSession(String id, int delta) {
    final order = [..._state!.sessionOrder];
    final index = order.indexOf(id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= order.length) return;
    final item = order.removeAt(index);
    order.insert(target, item);
    _setState(_state!.copyWith(sessionOrder: order));
  }

  Widget _newOutputCard() => CycleOutputBlock(
    programTitle: _state!.programTitle,
    showPlating: _state!.showPlating,
    busy: _busy,
    enabled: _valuesValid,
    isFrench: _isFrench,
    onProgramTitleChanged: (title) =>
        _setState(_state!.copyWith(programTitle: title)),
    onShowPlatingChanged: (value) =>
        _setState(_state!.copyWith(showPlating: value)),
    onGenerate: _generate,
    onExport: widget.application is CycleWebExportApplication ? _export : null,
  );

  // ignore: unused_element
  Widget _selectionCard() {
    final selectedTemplate = _index!.templates.singleWhere(
      (item) => item.id == _state!.templateId,
    );
    return _sectionCard(
      title: _isFrench ? 'MODÈLE' : 'TEMPLATE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const Key('cycle-web-template'),
            initialValue: _state!.templateId,
            isExpanded: true,
            style: _inputTextStyle,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              labelText: _isFrench ? 'Modèle' : 'Template',
            ),
            items: [
              for (final template in _index!.templates)
                DropdownMenuItem(
                  value: template.id,
                  child: Text(_templateLabel(template)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) _selectTemplate(value);
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('cycle-web-variant'),
            initialValue: _state!.variantId,
            isExpanded: true,
            style: _inputTextStyle,
            dropdownColor: Colors.white,
            decoration: InputDecoration(
              labelText: _isFrench ? 'Variante' : 'Variant',
            ),
            items: [
              for (final id in selectedTemplate.variantIds)
                DropdownMenuItem(value: id, child: Text(_humanize(id))),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) _selectVariant(value);
                  },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _optionsCard() {
    final visible = _schema!.options
        .where(
          (option) => CycleOptionConditionEvaluator.evaluate(
            option.visibleWhen,
            _state!.values,
          ),
        )
        .toList();
    return _sectionCard(
      title: _isFrench ? 'OPTIONS SUPPLÉMENTAIRES' : 'ADDITIONAL OPTIONS',
      child: visible.isEmpty
          ? Text(
              _isFrench
                  ? 'Aucune option supplémentaire pour cette variante.'
                  : 'No additional options for this variant.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 460
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 18) / columns;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    for (final option in visible)
                      SizedBox(
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _optionField(option),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  // ignore: unused_element
  Widget _outputCard() => _sectionCard(
    title: 'OUTPUT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_humanize(_state!.variantId)} · ${_movementIds.length} ${_isFrench ? 'mouvements' : 'movements'}',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            '$_error',
            key: const Key('cycle-web-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          key: const Key('cycle-web-generate'),
          onPressed: _busy || !_valuesValid ? null : _generate,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _isFrench ? 'Générer et sauvegarder' : 'Generate and save',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('cycle-web-export'),
          onPressed: widget.application is CycleWebExportApplication
              ? _export
              : null,
          icon: const Icon(Icons.download),
          label: Text(_isFrench ? 'Exporter' : 'Export'),
        ),
      ],
    ),
  );

  bool get _valuesValid =>
      _schema!.options.every((option) {
        if (!CycleOptionConditionEvaluator.evaluate(
          option.visibleWhen,
          _state!.values,
        )) {
          return true;
        }
        final value = _state!.values[option.id];
        final required = CycleOptionConditionEvaluator.evaluate(
          option.requiredWhen,
          _state!.values,
        );
        if (value == null || (value is String && value.trim().isEmpty)) {
          return !required;
        }
        if (value is num) {
          if (option.minimum != null && value < option.minimum!) return false;
          if (option.maximum != null && value > option.maximum!) return false;
        }
        return true;
      }) &&
      _state!.startDate != null &&
      _state!.trainingDays.length == _state!.sessionOrder.length &&
      _state!.trainingDays.toSet().length == _state!.trainingDays.length &&
      _state!.trainingDays.every((day) => day >= 1 && day <= 7) &&
      _state!.sessionOrder.toSet().length == _state!.sessionOrder.length &&
      _movementIds.every(
        (id) => (_state!.maxInputs[id]?.weightCentiUnits ?? 0) > 0,
      );

  // ignore: unused_element
  Widget _weightCard() => _sectionCard(
    title: _isFrench ? 'CHARGES' : 'WEIGHT',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SegmentedButton<CycleMaxInputKind>(
            key: const Key('cycle-web-max-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CycleMaxInputKind.oneRepMax,
                label: Text('1 RM'),
              ),
              ButtonSegment(
                value: CycleMaxInputKind.directTrainingMax,
                label: Text('TM'),
              ),
              ButtonSegment(
                value: CycleMaxInputKind.repMax,
                label: Text('Rep max'),
              ),
            ],
            selected: {_commonMaxKind},
            onSelectionChanged: (selection) =>
                _setAllMaxKinds(selection.single),
          ),
        ),
        const SizedBox(height: 16),
        for (final movementId in _movementIds) ...[
          _movementMaxFields(movementId),
          const SizedBox(height: 10),
        ],
        const Divider(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 205,
              child: _numberField(
                key: 'cycle-web-global-ratio',
                label: _isFrench
                    ? 'Ratio TM global (%)'
                    : 'Global TM ratio (%)',
                value: _state!.globalTrainingMaxRatioBasisPoints / 100,
                onValue: (value) => _setState(
                  _state!.copyWith(
                    globalTrainingMaxRatioBasisPoints: (value * 100).round(),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 135,
              child: DropdownButtonFormField<WeightUnit>(
                key: const Key('cycle-web-unit'),
                initialValue: _state!.unit,
                isExpanded: true,
                style: _inputTextStyle,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  labelText: _isFrench ? 'Unité' : 'Unit',
                ),
                items: WeightUnit.values
                    .map(
                      (unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit.name)),
                    )
                    .toList(),
                onChanged: (unit) {
                  if (unit != null) _setState(_state!.copyWith(unit: unit));
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );

  CycleMaxInputKind get _commonMaxKind {
    for (final movementId in _movementIds) {
      final kind = _state!.maxInputs[movementId]?.kind;
      if (kind != null) return kind;
    }
    return CycleMaxInputKind.oneRepMax;
  }

  void _setAllMaxKinds(CycleMaxInputKind kind) {
    final inputs = <String, CycleMovementMaxInput>{};
    for (final movementId in _movementIds) {
      final current =
          _state!.maxInputs[movementId] ??
          const CycleMovementMaxInput(
            kind: CycleMaxInputKind.oneRepMax,
            weightCentiUnits: 0,
          );
      inputs[movementId] = CycleMovementMaxInput(
        kind: kind,
        weightCentiUnits: current.weightCentiUnits,
        repetitions: kind == CycleMaxInputKind.repMax
            ? (current.repetitions ?? 1)
            : null,
      );
    }
    _setState(_state!.copyWith(maxInputs: inputs));
  }

  Widget _movementMaxFields(String id) {
    final input =
        _state!.maxInputs[id] ??
        const CycleMovementMaxInput(
          kind: CycleMaxInputKind.oneRepMax,
          weightCentiUnits: 0,
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = <Widget>[
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<CycleMaxInputKind>(
              key: ValueKey('cycle-web-max-kind-$id'),
              initialValue: input.kind,
              isExpanded: true,
              style: _inputTextStyle,
              dropdownColor: Colors.white,
              decoration: const InputDecoration(isDense: true),
              items: CycleMaxInputKind.values
                  .map(
                    (kind) => DropdownMenuItem(
                      value: kind,
                      child: Text(
                        kind == CycleMaxInputKind.oneRepMax
                            ? '1 RM'
                            : kind == CycleMaxInputKind.directTrainingMax
                            ? 'TM'
                            : 'Rep max',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (kind) {
                if (kind != null) {
                  _setMovementInput(
                    id,
                    CycleMovementMaxInput(
                      kind: kind,
                      weightCentiUnits: input.weightCentiUnits,
                      repetitions: kind == CycleMaxInputKind.repMax
                          ? (input.repetitions ?? 1)
                          : null,
                    ),
                  );
                }
              },
            ),
          ),
          if (input.kind == CycleMaxInputKind.repMax)
            SizedBox(
              width: 78,
              child: _numberField(
                key: 'cycle-web-max-reps-$id',
                label: _isFrench ? 'Rép.' : 'Reps',
                value: (input.repetitions ?? 1).toDouble(),
                onValue: (value) => _setMovementInput(
                  id,
                  CycleMovementMaxInput(
                    kind: input.kind,
                    weightCentiUnits: input.weightCentiUnits,
                    repetitions: value.round(),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 92,
            child: _numberField(
              key: 'cycle-web-max-weight-$id',
              label: _state!.unit.name,
              value: input.weightCentiUnits / 100,
              onValue: (value) => _setMovementInput(
                id,
                CycleMovementMaxInput(
                  kind: input.kind,
                  weightCentiUnits: (value * 100).round(),
                  repetitions: input.repetitions,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 82,
            child: _numberField(
              key: 'cycle-web-ratio-$id',
              label: 'TM %',
              value:
                  (_state!.trainingMaxRatioByMovementBasisPoints[id] ??
                      _state!.globalTrainingMaxRatioBasisPoints) /
                  100,
              onValue: (value) => _setState(
                _state!.copyWith(
                  trainingMaxRatioByMovementBasisPoints: {
                    ..._state!.trainingMaxRatioByMovementBasisPoints,
                    id: (value * 100).round(),
                  },
                ),
              ),
            ),
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_humanize(id), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: fields),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _platingCard() => _sectionCard(
    title: _isFrench ? 'PLAQUES ET BARRE' : 'PLATING & BARBELL',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 14,
          children: [
            for (final plate in _plateChoices)
              SizedBox(
                width: 118,
                child: Column(
                  children: [
                    Text(
                      '${_formatWeight(plate)} ${_state!.unit.name}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: ValueKey('cycle-web-plate-remove-$plate'),
                          visualDensity: VisualDensity.compact,
                          tooltip: _isFrench
                              ? 'Retirer une plaque'
                              : 'Remove one plate',
                          onPressed: _plateCount(plate) == 0
                              ? null
                              : () => _changePlateCount(plate, -1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${_plateCount(plate)}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: ValueKey('cycle-web-plate-add-$plate'),
                          visualDensity: VisualDensity.compact,
                          tooltip: _isFrench
                              ? 'Ajouter une plaque'
                              : 'Add one plate',
                          onPressed: () => _changePlateCount(plate, 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        const Divider(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 190,
              child: _numberField(
                key: 'cycle-web-bar',
                label: _isFrench ? 'Poids de la barre' : 'Barbell weight',
                value: _state!.barWeightCentiUnits / 100,
                onValue: (value) => _setState(
                  _state!.copyWith(barWeightCentiUnits: (value * 100).round()),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: _numberField(
                key: 'cycle-web-rounding',
                label: _isFrench ? 'Incrément d’arrondi' : 'Rounding increment',
                value: _state!.roundingIncrementCentiUnits / 100,
                onValue: (value) => _setState(
                  _state!.copyWith(
                    roundingIncrementCentiUnits: (value * 100).round(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('cycle-web-plates'),
          style: _inputTextStyle,
          initialValue: _state!.platesPerSideCentiUnits
              .map((value) => value / 100)
              .join(','),
          decoration: InputDecoration(
            labelText: _isFrench ? 'Plaques par côté' : 'Plates per side',
          ),
          onChanged: (text) => _setState(
            _state!.copyWith(
              platesPerSideCentiUnits: text
                  .split(',')
                  .map((value) => double.tryParse(value.trim()))
                  .whereType<double>()
                  .map((value) => (value * 100).round())
                  .toList(),
            ),
          ),
        ),
      ],
    ),
  );

  List<int> get _plateChoices {
    final defaults = _state!.unit == WeightUnit.kg
        ? const [
            5000,
            2500,
            2000,
            1500,
            1000,
            500,
            250,
            200,
            150,
            125,
            100,
            75,
            50,
            25,
          ]
        : const [4500, 3500, 2500, 1000, 500, 250, 125];
    return {...defaults, ..._state!.platesPerSideCentiUnits}.toList()
      ..sort((left, right) => right.compareTo(left));
  }

  int _plateCount(int plate) =>
      _state!.platesPerSideCentiUnits.where((value) => value == plate).length;

  void _changePlateCount(int plate, int delta) {
    final plates = [..._state!.platesPerSideCentiUnits];
    if (delta > 0) {
      plates.add(plate);
    } else {
      plates.remove(plate);
    }
    plates.sort((left, right) => right.compareTo(left));
    _setState(_state!.copyWith(platesPerSideCentiUnits: plates));
  }

  String _formatWeight(int centiUnits) {
    final value = centiUnits / 100;
    return value == value.roundToDouble()
        ? '${value.round()}'
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  // ignore: unused_element
  Widget _schedulingCard() => _sectionCard(
    title: _isFrench ? 'PLANIFICATION' : 'SCHEDULING',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('cycle-web-start-date'),
          style: _inputTextStyle,
          initialValue: _state!.startDate?.toIso8601String().substring(0, 10),
          decoration: InputDecoration(
            labelText: _isFrench ? 'Date de début' : 'Start date',
          ),
          onChanged: (text) {
            final date = DateTime.tryParse(text);
            if (date != null) _setState(_state!.copyWith(startDate: date));
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('cycle-web-training-days'),
          style: _inputTextStyle,
          initialValue: _state!.trainingDays.join(','),
          decoration: InputDecoration(
            labelText: _isFrench ? 'Jours (1–7)' : 'Days (1–7)',
            helperText: _isFrench
                ? 'Séparés par des virgules'
                : 'Comma separated',
          ),
          onChanged: (text) {
            final days = text
                .split(',')
                .map((value) => int.tryParse(value.trim()))
                .whereType<int>()
                .where((value) => value >= 1 && value <= 7)
                .toList();
            _setState(_state!.copyWith(trainingDays: days));
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('cycle-web-session-order'),
          style: _inputTextStyle,
          initialValue: _state!.sessionOrder.join(','),
          decoration: InputDecoration(
            labelText: _isFrench ? 'Ordre des séances' : 'Session order',
            helperText: _state!.sessionOrder.join(', '),
          ),
          onChanged: (text) {
            final order = text
                .split(',')
                .map((value) => value.trim())
                .where(_state!.sessionOrder.contains)
                .toList();
            _setState(_state!.copyWith(sessionOrder: order));
          },
        ),
      ],
    ),
  );

  void _setMovementInput(String id, CycleMovementMaxInput input) =>
      _setState(_state!.copyWith(maxInputs: {..._state!.maxInputs, id: input}));

  TextStyle get _inputTextStyle => const TextStyle(
    color: HybridGeneratorTokens.background,
    fontWeight: FontWeight.w600,
  );

  Widget _numberField({
    required String key,
    required String label,
    required double value,
    required ValueChanged<double> onValue,
  }) => TextFormField(
    key: ValueKey(key),
    initialValue: '$value',
    style: _inputTextStyle,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    onChanged: (text) {
      final parsed = double.tryParse(text);
      if (parsed != null && parsed >= 0) onValue(parsed);
    },
  );

  Widget _optionField(CycleOptionDefinition option) {
    final enabled = CycleOptionConditionEvaluator.evaluate(
      option.enabledWhen,
      _state!.values,
    );
    final value = _state!.values[option.id] ?? option.defaultValue;
    final localizedLabel = _isFrench ? option.labelFr : option.labelEn;
    final label = localizedLabel.isEmpty
        ? _humanize(option.id)
        : localizedLabel;
    if (option.scope == CycleOptionScope.perMovement) {
      final values = value as Map<Object?, Object?>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label),
          for (final movementId in _movementIds)
            _numberField(
              key: 'cycle-option-${option.id}-$movementId',
              label: _humanize(movementId),
              value: _optionNumberForDisplay(
                option,
                (values[movementId] as num?)?.toDouble() ?? 0,
              ),
              onValue: (next) => _setOption(option.id, {
                ...values,
                movementId: _optionNumberFromDisplay(option, next),
              }),
            ),
        ],
      );
    }
    if (option.type == CycleOptionType.boolean) {
      return SwitchListTile(
        key: ValueKey('cycle-option-${option.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value as bool,
        onChanged: enabled ? (next) => _setOption(option.id, next) : null,
      );
    }
    if (option.allowedValues.isNotEmpty &&
        (option.type == CycleOptionType.enumeration ||
            option.type == CycleOptionType.movement ||
            option.type == CycleOptionType.exercise ||
            option.type == CycleOptionType.prescription)) {
      return DropdownButtonFormField<Object>(
        key: ValueKey('cycle-option-${option.id}'),
        initialValue: value,
        isExpanded: true,
        style: _inputTextStyle,
        dropdownColor: Colors.white,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final allowed in option.allowedValues)
            DropdownMenuItem(
              value: allowed,
              child: Text(_humanize('$allowed')),
            ),
        ],
        onChanged: enabled
            ? (next) {
                if (next != null) _setOption(option.id, next);
              }
            : null,
      );
    }
    return TextFormField(
      key: ValueKey('cycle-option-${option.id}'),
      initialValue: value is num
          ? '${_optionNumberForDisplay(option, value.toDouble())}'
          : '$value',
      style: _inputTextStyle,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: _bounds(option),
        suffixText: option.type == CycleOptionType.percentage ? '%' : null,
      ),
      onChanged: (text) {
        final parsed = option.type == CycleOptionType.integer
            ? int.tryParse(text)
            : double.tryParse(text);
        if (parsed != null) {
          _setOption(
            option.id,
            _optionNumberFromDisplay(option, parsed.toDouble()),
          );
        }
      },
    );
  }

  double _optionNumberForDisplay(CycleOptionDefinition option, double value) =>
      option.type == CycleOptionType.percentage ? value / 100 : value;

  num _optionNumberFromDisplay(CycleOptionDefinition option, double value) =>
      option.type == CycleOptionType.percentage
      ? (value * 100).round()
      : option.type == CycleOptionType.integer
      ? value.round()
      : value;

  String? _bounds(CycleOptionDefinition option) {
    if (option.minimum == null && option.maximum == null) return null;
    final minimum = option.minimum == null
        ? '−∞'
        : _optionNumberForDisplay(
            option,
            option.minimum!.toDouble(),
          ).toString();
    final maximum = option.maximum == null
        ? '∞'
        : _optionNumberForDisplay(
            option,
            option.maximum!.toDouble(),
          ).toString();
    return '$minimum – $maximum';
  }

  String _templateLabel(CycleTemplateSummary template) =>
      _isFrench ? template.labelFr : template.labelEn;

  String _humanize(String value) {
    final spaced = value.replaceAll('_', ' ').trim();
    return spaced.isEmpty
        ? value
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

/// The catalogue-driven Cycle editor used by both generator pages.
///
/// It deliberately excludes the page shell and generation actions. Every
/// change is persisted through [application] and reported through [onChanged].
class CycleEditorPanel extends StatelessWidget {
  const CycleEditorPanel({
    required this.application,
    required this.initialState,
    required this.onChanged,
    super.key,
  });

  final CycleWebApplication application;
  final CycleEditorState initialState;
  final ValueChanged<CycleEditorState> onChanged;

  @override
  Widget build(BuildContext context) => CycleWebPage(
    application: application,
    initialState: initialState,
    onStateChanged: onChanged,
    embedded: true,
  );
}

// ignore: unused_element
class _CyclePreview extends StatelessWidget {
  const _CyclePreview({required this.view, required this.isFrench});
  final GeneratedCycleView view;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: isFrench ? 'Aperçu du cycle généré' : 'Generated cycle preview',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final gap = 12.0;
        final sessionWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isFrench ? 'Aperçu sauvegardé' : 'Saved preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final week in view.cycle.weeks) ...[
              Text(
                '${isFrench ? 'SEMAINE' : 'WEEK'} ${week.number}',
                key: ValueKey('cycle-preview-week-${week.number}'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final session in week.sessions)
                    SizedBox(
                      width: sessionWidth,
                      child: _CycleSessionPreview(
                        session: session,
                        setDescription: _setDescription,
                        isFrench: isFrench,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    ),
  );

  String _setDescription(GeneratedSet set) {
    final load = set.plannedLoad;
    final loadText = load == null
        ? '—'
        : '${load.value.toStringAsFixed(2)} ${load.unit.name}';
    final plates = set.platesPerSide.isEmpty
        ? '—'
        : set.platesPerSide
              .map((plate) => plate.value.toStringAsFixed(2))
              .join(' + ');
    return '${isFrench ? 'Série' : 'Set'} ${set.index}: '
        '${set.repetitions} · $loadText · '
        '${isFrench ? 'plaques/côté' : 'plates/side'} $plates';
  }
}

class _CycleSessionPreview extends StatelessWidget {
  const _CycleSessionPreview({
    required this.session,
    required this.setDescription,
    required this.isFrench,
  });

  final GeneratedSession session;
  final String Function(GeneratedSet) setDescription;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('cycle-preview-session-${session.id}'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: HybridGeneratorTokens.surfaceMuted.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          session.movementId.value.replaceAll('_', ' ').toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          session.date.toIso8601String().substring(0, 10),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final block in session.blocks) ...[
          Text(
            '${block.role} · ${block.movementId.value.replaceAll('_', ' ')}',
            key: ValueKey('cycle-preview-block-${block.id}'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          for (final set in block.sets)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: HybridGeneratorTokens.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                setDescription(set),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 7),
        ],
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.error,
    required this.onRetry,
    required this.isFrench,
  });
  final Object? error;
  final VoidCallback onRetry;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isFrench ? 'Impossible de charger le catalogue' : 'Unable to load catalogue'}${error == null ? '' : ': $error'}',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(isFrench ? 'Réessayer' : 'Retry'),
          ),
        ],
      ),
    ),
  );
}
