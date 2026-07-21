import 'package:flutter/material.dart';

import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_option_schema.dart';
import '../../training_catalog/domain/catalog_index.dart';
import '../application/cycle_option_condition_evaluator.dart';
import '../application/cycle_web_contract.dart';

class CycleWebPage extends StatefulWidget {
  const CycleWebPage({
    required this.application,
    this.foreverRoute = '/poc/531/generator?mode=forever',
    super.key,
  });

  final CycleWebApplication application;
  final String foreverRoute;

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
      final draft = await widget.application.loadDraft();
      final selection = _validSelection(index, draft);
      final schema = await widget.application.loadEditorSchema(
        templateId: selection.templateId,
        variantId: selection.variantId,
      );
      final movementIds = await widget.application.loadMovementIds(
        templateId: selection.templateId,
        variantId: selection.variantId,
      );
      final values = {
        for (final option in schema.options)
          option.id: draft?.values[option.id] ?? option.defaultValue,
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
          trainingDays: draft?.trainingDays ?? const [1, 3, 5],
          sessionOrder: draft?.sessionOrder ?? movementIds,
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
          cycleId:
              draft?.cycleId ??
              'cycle-${DateTime.now().toUtc().microsecondsSinceEpoch}',
        );
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
      final state = CycleEditorState(
        templateId: templateId,
        variantId: variantId,
        values: {
          for (final option in schema.options) option.id: option.defaultValue,
        },
        startDate: _state?.startDate ?? DateTime.now(),
        trainingDays: _state?.trainingDays ?? const [1, 3, 5],
        sessionOrder: movementIds,
        unit: _state?.unit ?? WeightUnit.kg,
        globalTrainingMaxRatioBasisPoints:
            _state?.globalTrainingMaxRatioBasisPoints ?? 9000,
        roundingIncrementCentiUnits: _state?.roundingIncrementCentiUnits ?? 250,
        barWeightCentiUnits: _state?.barWeightCentiUnits ?? 2000,
        platesPerSideCentiUnits: _state?.platesPerSideCentiUnits ?? const [],
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

  Future<void> _setOption(String id, Object value) async {
    final state = _state!.copyWith(values: {..._state!.values, id: value});
    await _setState(state);
  }

  Future<void> _setState(CycleEditorState state) async {
    setState(() {
      _state = state;
      _generated = null;
    });
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

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('cycle-web-page'),
    appBar: AppBar(
      title: Text(_isFrench ? 'Générateur de cycle' : 'Cycle generator'),
      actions: [
        TextButton(
          key: const Key('cycle-web-forever'),
          onPressed: () => Navigator.of(context).pushNamed(widget.foreverRoute),
          child: const Text('FOREVER'),
        ),
      ],
    ),
    body: SafeArea(child: _body()),
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
        final selection = _selectionCard();
        final editor = _editorCard();
        final content = constraints.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: selection),
                  const SizedBox(width: 20),
                  Expanded(child: editor),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [selection, const SizedBox(height: 16), editor],
              );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _selectionCard() {
    final selectedTemplate = _index!.templates.singleWhere(
      (item) => item.id == _state!.templateId,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isFrench ? 'Programme' : 'Program',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('cycle-web-template'),
              initialValue: _state!.templateId,
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
      ),
    );
  }

  Widget _editorCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isFrench ? 'Configuration' : 'Configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _requestFields(),
          const SizedBox(height: 20),
          for (final option in _schema!.options)
            if (CycleOptionConditionEvaluator.evaluate(
              option.visibleWhen,
              _state!.values,
            )) ...[
              _optionField(option),
              const SizedBox(height: 12),
            ],
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
          if (_generated case final generated?) ...[
            const SizedBox(height: 20),
            _CyclePreview(view: generated, isFrench: _isFrench),
          ],
        ],
      ),
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
      _state!.trainingDays.isNotEmpty &&
      _movementIds.every(
        (id) => (_state!.maxInputs[id]?.weightCentiUnits ?? 0) > 0,
      );

  Widget _requestFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _isFrench ? 'Max et matériel' : 'Maxes and equipment',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<WeightUnit>(
        key: const Key('cycle-web-unit'),
        initialValue: _state!.unit,
        decoration: InputDecoration(labelText: _isFrench ? 'Unité' : 'Unit'),
        items: WeightUnit.values
            .map(
              (unit) => DropdownMenuItem(value: unit, child: Text(unit.name)),
            )
            .toList(),
        onChanged: (unit) {
          if (unit != null) _setState(_state!.copyWith(unit: unit));
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('cycle-web-start-date'),
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
              .map((v) => int.tryParse(v.trim()))
              .whereType<int>()
              .where((v) => v >= 1 && v <= 7)
              .toList();
          _setState(_state!.copyWith(trainingDays: days));
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('cycle-web-session-order'),
        initialValue: _state!.sessionOrder.join(','),
        decoration: InputDecoration(
          labelText: _isFrench ? 'Ordre des séances' : 'Session order',
          helperText: _movementIds.join(', '),
        ),
        onChanged: (text) {
          final order = text
              .split(',')
              .map((value) => value.trim())
              .where(_movementIds.contains)
              .toList();
          _setState(_state!.copyWith(sessionOrder: order));
        },
      ),
      const SizedBox(height: 12),
      for (final movementId in _movementIds) ...[
        _movementMaxFields(movementId),
        const SizedBox(height: 12),
      ],
      _numberField(
        key: 'cycle-web-global-ratio',
        label: _isFrench ? 'Ratio TM global (%)' : 'Global TM ratio (%)',
        value: _state!.globalTrainingMaxRatioBasisPoints / 100,
        onValue: (value) => _setState(
          _state!.copyWith(
            globalTrainingMaxRatioBasisPoints: (value * 100).round(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _numberField(
        key: 'cycle-web-bar',
        label: _isFrench ? 'Barre' : 'Bar',
        value: _state!.barWeightCentiUnits / 100,
        onValue: (value) => _setState(
          _state!.copyWith(barWeightCentiUnits: (value * 100).round()),
        ),
      ),
      const SizedBox(height: 12),
      _numberField(
        key: 'cycle-web-rounding',
        label: _isFrench ? 'Arrondi' : 'Rounding',
        value: _state!.roundingIncrementCentiUnits / 100,
        onValue: (value) => _setState(
          _state!.copyWith(roundingIncrementCentiUnits: (value * 100).round()),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const Key('cycle-web-plates'),
        initialValue: _state!.platesPerSideCentiUnits
            .map((v) => v / 100)
            .join(','),
        decoration: InputDecoration(
          labelText: _isFrench ? 'Plaques par côté' : 'Plates per side',
        ),
        onChanged: (text) => _setState(
          _state!.copyWith(
            platesPerSideCentiUnits: text
                .split(',')
                .map((v) => double.tryParse(v.trim()))
                .whereType<double>()
                .map((v) => (v * 100).round())
                .toList(),
          ),
        ),
      ),
    ],
  );

  Widget _movementMaxFields(String id) {
    final input =
        _state!.maxInputs[id] ??
        const CycleMovementMaxInput(
          kind: CycleMaxInputKind.oneRepMax,
          weightCentiUnits: 0,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_humanize(id), style: Theme.of(context).textTheme.titleSmall),
        DropdownButtonFormField<CycleMaxInputKind>(
          key: ValueKey('cycle-web-max-kind-$id'),
          initialValue: input.kind,
          items: CycleMaxInputKind.values
              .map(
                (kind) => DropdownMenuItem(
                  value: kind,
                  child: Text(_humanize(kind.name)),
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
        const SizedBox(height: 8),
        _numberField(
          key: 'cycle-web-max-weight-$id',
          label: _isFrench ? 'Charge' : 'Weight',
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
        if (input.kind == CycleMaxInputKind.repMax) ...[
          const SizedBox(height: 8),
          _numberField(
            key: 'cycle-web-max-reps-$id',
            label: _isFrench ? 'Répétitions' : 'Repetitions',
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
        ],
        const SizedBox(height: 8),
        _numberField(
          key: 'cycle-web-ratio-$id',
          label: _isFrench
              ? 'Ratio TM spécifique (%)'
              : 'Movement TM ratio (%)',
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
      ],
    );
  }

  void _setMovementInput(String id, CycleMovementMaxInput input) =>
      _setState(_state!.copyWith(maxInputs: {..._state!.maxInputs, id: input}));

  Widget _numberField({
    required String key,
    required String label,
    required double value,
    required ValueChanged<double> onValue,
  }) => TextFormField(
    key: ValueKey(key),
    initialValue: '$value',
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
    final label = _humanize(option.id);
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
              value: (values[movementId] as num?)?.toDouble() ?? 0,
              onValue: (next) =>
                  _setOption(option.id, {...values, movementId: next}),
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
      initialValue: '$value',
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
        if (parsed != null) _setOption(option.id, parsed);
      },
    );
  }

  String? _bounds(CycleOptionDefinition option) {
    if (option.minimum == null && option.maximum == null) return null;
    return '${option.minimum ?? '−∞'} – ${option.maximum ?? '∞'}';
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

class _CyclePreview extends StatelessWidget {
  const _CyclePreview({required this.view, required this.isFrench});
  final GeneratedCycleView view;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: isFrench ? 'Aperçu du cycle généré' : 'Generated cycle preview',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isFrench ? 'Aperçu sauvegardé' : 'Saved preview',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final week in view.cycle.weeks)
          ExpansionTile(
            key: ValueKey('cycle-preview-week-${week.number}'),
            title: Text('${isFrench ? 'Semaine' : 'Week'} ${week.number}'),
            children: [
              for (final session in week.sessions)
                ListTile(
                  title: Text(session.movementId.value.replaceAll('_', ' ')),
                  subtitle: Text(
                    '${session.date.toIso8601String().substring(0, 10)} · ${session.blocks.length} ${isFrench ? 'blocs' : 'blocks'}',
                  ),
                ),
            ],
          ),
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
