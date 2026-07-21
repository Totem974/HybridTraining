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
      final values = {
        for (final option in schema.options)
          option.id: draft?.values[option.id] ?? option.defaultValue,
      };
      if (!mounted) return;
      setState(() {
        _index = index;
        _schema = schema;
        _state = CycleEditorState(
          templateId: selection.templateId,
          variantId: selection.variantId,
          values: values,
        );
        _busy = false;
      });
    } on Object catch (error) {
      if (mounted)
        setState(() {
          _error = error;
          _busy = false;
        });
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
      final state = CycleEditorState(
        templateId: templateId,
        variantId: variantId,
        values: {
          for (final option in schema.options) option.id: option.defaultValue,
        },
      );
      await widget.application.saveDraft(state);
      if (!mounted) return;
      setState(() {
        _schema = schema;
        _state = state;
        _busy = false;
      });
    } on Object catch (error) {
      if (mounted)
        setState(() {
          _error = error;
          _busy = false;
        });
    }
  }

  Future<void> _setOption(String id, Object value) async {
    final state = CycleEditorState(
      templateId: _state!.templateId,
      variantId: _state!.variantId,
      values: {..._state!.values, id: value},
    );
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
      if (mounted)
        setState(() {
          _generated = generated;
          _busy = false;
        });
    } on Object catch (error) {
      if (mounted)
        setState(() {
          _error = error;
          _busy = false;
        });
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
              value: _state!.templateId,
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
              value: _state!.variantId,
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

  bool get _valuesValid => _schema!.options.every((option) {
    if (!CycleOptionConditionEvaluator.evaluate(
      option.visibleWhen,
      _state!.values,
    ))
      return true;
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
  });

  Widget _optionField(CycleOptionDefinition option) {
    final enabled = CycleOptionConditionEvaluator.evaluate(
      option.enabledWhen,
      _state!.values,
    );
    final value = _state!.values[option.id] ?? option.defaultValue;
    final label = _humanize(option.id);
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
        value: value,
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
