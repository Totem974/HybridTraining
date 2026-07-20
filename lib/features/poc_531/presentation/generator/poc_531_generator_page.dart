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
    this.classicTemplates = const [],
    this.foreverTemplates = const [],
    this.programs = const [],
    this.supplemental = const [],
    this.assistance = const [],
    this.conditioning = const [],
    this.transitions = const [],
  });
  final List<CalculatorTemplateChoice> classicTemplates;
  final List<ForeverTemplateChoice> foreverTemplates;
  // Legacy fields keep route/widget fakes source-compatible while the real
  // adapter exclusively uses the calculator contracts above.
  final List<ProgramChoice> programs;
  final List<String> supplemental, assistance, conditioning, transitions;
}

class CalculatorTemplateChoice {
  const CalculatorTemplateChoice({
    required this.id,
    required this.name,
    required this.allowedDays,
    required this.variants,
  });
  final String id, name;
  final List<int> allowedDays;
  final List<CalculatorVariantChoice> variants;
}

class CalculatorVariantChoice {
  const CalculatorVariantChoice({
    required this.id,
    required this.name,
    required this.executable,
    required this.allowedDays,
    this.blockedReason,
  });
  final String id, name;
  final bool executable;
  final List<int> allowedDays;
  final String? blockedReason;
}

class ForeverTemplateChoice {
  const ForeverTemplateChoice({
    required this.id,
    required this.name,
    required this.variant,
    required this.executable,
    required this.sequence,
    this.days,
    this.blockedReason,
  });
  final String id, name, variant;
  final bool executable;
  final int? days;
  final String? blockedReason;
  final List<String> sequence;
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
  final String id, name, generation, family, variant, status;
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
  final String title, explanation, exportJson;
  final List<PlanBlockView> blocks;
  final List<String> sources;
  final List<GeneratorWarning> warnings;
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
  final double actualWeight, roundingError;
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
  State<Poc531GeneratorPage> createState() => _CalculatorState();
}

class _CalculatorState extends State<Poc531GeneratorPage> {
  static const _lifts = ['Press', 'Bench Press', 'Squat', 'Deadlift'];
  static const _liftIds = ['press', 'bench', 'squat', 'deadlift'];
  final _form = GlobalKey<FormState>();
  final _weights = {
    'Press': TextEditingController(text: '50'),
    'Bench Press': TextEditingController(text: '100'),
    'Squat': TextEditingController(text: '150'),
    'Deadlift': TextEditingController(text: '200'),
  };
  final _reps = {
    for (final lift in _lifts) lift: TextEditingController(text: '1'),
  };
  final _ratio = TextEditingController(text: '90');
  final _simplestStrengthRatio = TextEditingController(text: '90');
  final _warmupBaseUpper = TextEditingController(text: '95');
  final _warmupBaseLower = TextEditingController(text: '135');
  final _simplestStrengthWeights = {
    'Close Grip Bench': TextEditingController(text: '50'),
    'Incline Press': TextEditingController(text: '75'),
    'Front Squat': TextEditingController(text: '100'),
    'Straight Leg Deadlift': TextEditingController(text: '125'),
  };
  final _simplestStrengthReps = {
    for (final lift in const [
      'Close Grip Bench',
      'Incline Press',
      'Front Squat',
      'Straight Leg Deadlift',
    ])
      lift: TextEditingController(text: '1'),
  };
  final _bar = TextEditingController(text: '20');
  final _plateCounts = <double, int>{
    50: 0,
    25: 2,
    20: 2,
    15: 0,
    10: 2,
    5: 2,
    2.5: 2,
    2: 0,
    1.5: 0,
    1.25: 2,
    1: 0,
    .75: 0,
    .5: 0,
    .25: 0,
    .125: 0,
  };
  String _mode = 'classic', _input = 'oneRm', _unit = 'kg';
  String _simplestStrengthInput = 'oneRm';
  String? _templateId, _variantId, _foreverId;
  int _days = 4, _supplemental = 50, _jokerCap = 10;
  int _bodyweightTotalReps = 75, _bodyweightSetCount = 5;
  int _fslSetCount = 3, _fslRepetitions = 5, _gvtRatio = 30;
  String _warmup = 'original', _deload = 'deload1', _weekOrder = '531';
  bool _jokers = false,
      _skipDeloadWarmup = false,
      _gvtAlternateExercise = false,
      _gvtUseSameRatio = true,
      _bbbUseSameRatio = true,
      _beginnerIntermediate = false,
      _bastardWorkOrder = false,
      _busy = false;
  final List<String> _liftOrder = List.of(_liftIds);
  final Map<String, int> _gvtRatiosByLift = {
    for (final lift in _liftIds) lift: 30,
  };
  final Map<String, int> _bbbRatiosByLift = {
    for (final lift in _liftIds) lift: 50,
  };
  List<GeneratorWarning> _warnings = const [];
  GeneratorResult? _result;
  PlateLoadingView? _loading;
  int _requestRevision = 0;
  int? _busyRevision;

  List<CalculatorTemplateChoice> get _classic {
    if (widget.core.options.classicTemplates.isNotEmpty) {
      return widget.core.options.classicTemplates;
    }
    return [
      for (final p in widget.core.options.programs.where(
        (p) => p.generation != 'forever',
      ))
        CalculatorTemplateChoice(
          id: p.id,
          name: p.name,
          allowedDays: const [2, 3, 4],
          variants: [
            CalculatorVariantChoice(
              id: p.id,
              name: p.variant,
              executable: true,
              allowedDays: const [2, 3, 4],
            ),
          ],
        ),
    ];
  }

  List<ForeverTemplateChoice> get _forever {
    if (widget.core.options.foreverTemplates.isNotEmpty) {
      return widget.core.options.foreverTemplates;
    }
    return [
      for (final p in widget.core.options.programs.where(
        (p) => p.generation == 'forever',
      ))
        ForeverTemplateChoice(
          id: p.id,
          name: p.name,
          variant: p.variant,
          executable: true,
          sequence: const ['Leader / Anchor'],
        ),
    ];
  }

  CalculatorTemplateChoice? get _template =>
      _classic.where((e) => e.id == _templateId).firstOrNull;
  CalculatorVariantChoice? get _variant =>
      _template?.variants.where((e) => e.id == _variantId).firstOrNull;
  ForeverTemplateChoice? get _foreverTemplate =>
      _forever.where((e) => e.id == _foreverId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _templateId = _classic.firstOrNull?.id;
    _variantId = _classic.firstOrNull?.variants
        .where((v) => v.executable)
        .firstOrNull
        ?.id;
    _foreverId = _forever.where((e) => e.executable).firstOrNull?.id;
    _restore(widget.initialConfiguration ?? const {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
  }

  @override
  void dispose() {
    for (final c in [
      ..._weights.values,
      ..._reps.values,
      ..._simplestStrengthWeights.values,
      ..._simplestStrengthReps.values,
      _ratio,
      _simplestStrengthRatio,
      _warmupBaseUpper,
      _warmupBaseLower,
      _bar,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _configuration => {
    'schemaVersion': 2,
    'mode': _mode,
    'unit': _unit,
    'inputMode': _input,
    'trainingMaxRatio': double.tryParse(_ratio.text),
    'templateId': _templateId,
    'variantId': _variantId,
    'foreverTemplateId': _foreverId,
    'days': _days,
    'supplementalPercent': _supplemental,
    'bbbUseSameRatio': _bbbUseSameRatio,
    'bbbRatiosByLift': _bbbRatiosByLift,
    'beginnerIntermediate': _beginnerIntermediate,
    'bodyweightTotalReps': _bodyweightTotalReps,
    'bodyweightSetCount': _bodyweightSetCount,
    'simplestStrengthInputMode': _simplestStrengthInput,
    'simplestStrengthTrainingMaxRatio': double.tryParse(
      _simplestStrengthRatio.text,
    ),
    'simplestStrengthLifts': {
      for (final entry in _simplestStrengthWeights.entries)
        entry.key: double.tryParse(entry.value.text),
    },
    'simplestStrengthRepetitions': {
      for (final entry in _simplestStrengthReps.entries)
        entry.key: int.tryParse(entry.value.text),
    },
    'fslSetCount': _fslSetCount,
    'fslRepetitions': _fslRepetitions,
    'gvtAlternateExercise': _gvtAlternateExercise,
    'gvtUseSameRatio': _gvtUseSameRatio,
    'gvtRatio': _gvtRatio,
    'gvtRatiosByLift': _gvtRatiosByLift,
    'liftOrder': _liftOrder,
    'weekOrder': _weekOrder,
    'bastardWorkOrder': _bastardWorkOrder,
    'warmup': _warmup,
    'warmupBaseUpper': double.tryParse(_warmupBaseUpper.text),
    'warmupBaseLower': double.tryParse(_warmupBaseLower.text),
    'jokersEnabled': _jokers,
    'jokerIncrement': 5,
    'jokerCap': _jokerCap,
    'deload': _deload,
    'skipDeloadWarmup': _skipDeloadWarmup,
    'lifts': {
      for (final lift in _lifts) lift: double.tryParse(_weights[lift]!.text),
    },
    'repetitions': {
      for (final lift in _lifts) lift: int.tryParse(_reps[lift]!.text),
    },
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('poc-531-generator'),
    backgroundColor: const Color(0xff181818),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xff2c9eff),
                    brightness: Brightness.dark,
                    surface: const Color(0xff323232),
                  ),
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: TextStyle(color: Color(0xff3d4652)),
                    floatingLabelStyle: TextStyle(
                      color: Color(0xff9ed4ff),
                      backgroundColor: Color(0xff323232),
                      fontWeight: FontWeight.w700,
                    ),
                    hintStyle: TextStyle(color: Color(0xff5f6874)),
                    suffixStyle: TextStyle(color: Color(0xff3d4652)),
                    prefixStyle: TextStyle(color: Color(0xff3d4652)),
                    errorStyle: TextStyle(color: Color(0xffffb4ab)),
                    border: OutlineInputBorder(),
                  ),
                  segmentedButtonTheme: SegmentedButtonThemeData(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : const Color(0xff727272),
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xff323232)
                            : const Color(0xfff0f0f0),
                      ),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, box) => box.maxWidth > 850
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _weight()),
                                const SizedBox(width: 18),
                                Expanded(child: _templatePanel()),
                              ],
                            )
                          : Column(
                              children: [
                                _weight(),
                                const SizedBox(height: 18),
                                _templatePanel(),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    _heading('ADDITIONAL OPTIONS'),
                    _additional(),
                    const SizedBox(height: 24),
                    _heading('PLATING & BARBELL'),
                    _plating(),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, box) => box.maxWidth > 700
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _heading('SCHEDULING'),
                                      _scheduling(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _heading('OUTPUT'),
                                      _outputActions(),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _heading('SCHEDULING'),
                                _scheduling(),
                                const SizedBox(height: 18),
                                _heading('OUTPUT'),
                                _outputActions(),
                              ],
                            ),
                    ),
                    if (_warnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      for (final w in _warnings) _notice(w),
                    ],
                    const SizedBox(height: 26),
                    _heading('PROGRAM'),
                    _program(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xff2c9eff),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.fitness_center, color: Color(0xff181818)),
      ),
      const SizedBox(width: 16),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HYBRID 5/3/1',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'CALCULATOR',
              style: TextStyle(
                color: Color(0xff2c9eff),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      value,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    ),
  );
  Widget _card(Widget child) => Material(
    color: const Color(0xff323232),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xff727272)),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Color(0xfff5f5f5)),
      child: IconTheme.merge(
        data: const IconThemeData(color: Color(0xfff5f5f5)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
  TextStyle get _label =>
      const TextStyle(color: Color(0xfff0f0f0), fontWeight: FontWeight.w700);
  TextStyle get _inputTextStyle =>
      const TextStyle(color: Color(0xff181818), fontWeight: FontWeight.w600);

  Widget _weight() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('WEIGHT'),
      _card(
        Form(
          key: _form,
          child: Column(
            children: [
              SegmentedButton<String>(
                key: const Key('input-mode'),
                segments: const [
                  ButtonSegment(value: 'oneRm', label: Text('1 Rep Max')),
                  ButtonSegment(value: 'tm', label: Text('Training Max')),
                  ButtonSegment(value: 'plusSet', label: Text('1+ Set')),
                ],
                selected: {_input},
                onSelectionChanged: (v) {
                  setState(() => _input = v.first);
                  _changed();
                },
              ),
              const SizedBox(height: 14),
              for (final lift in _lifts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(width: 118, child: Text(lift, style: _label)),
                      if (_input == 'oneRm')
                        SizedBox(
                          width: 58,
                          child: TextFormField(
                            key: ValueKey('reps-$lift'),
                            controller: _reps[lift],
                            style: _inputTextStyle,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              suffixText: '×',
                            ),
                            onChanged: (_) => _changed(),
                          ),
                        ),
                      if (_input == 'oneRm') const SizedBox(width: 6),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('lift-$lift'),
                          controller: _weights[lift],
                          style: _inputTextStyle,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: _unit,
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                              ? 'Charge requise'
                              : null,
                          onChanged: (_) => _changed(),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('tm-ratio'),
                      controller: _ratio,
                      style: _inputTextStyle,
                      enabled: _input != 'tm',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Training Max Ratio',
                        suffixText: '%',
                        isDense: true,
                      ),
                      onChanged: (_) => _changed(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'lb', label: Text('lb')),
                      ButtonSegment(value: 'kg', label: Text('kg')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (v) {
                      setState(() => _unit = v.first);
                      _changed();
                    },
                  ),
                ],
              ),
              if (_input == 'plusSet')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Le poids 1+ correspond à 95% du Training Max, comme dans la calculatrice de référence.',
                    style: TextStyle(color: Color(0xfff0f0f0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _templatePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('TEMPLATE'),
      _card(
        Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'classic', label: Text('Classic')),
                ButtonSegment(value: 'forever', label: Text('Forever')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) {
                setState(() {
                  _mode = v.first;
                  _result = null;
                  _syncDays();
                });
                _changed();
              },
            ),
            const SizedBox(height: 14),
            if (_mode == 'classic') ...[
              DropdownButtonFormField<String>(
                key: const Key('program'),
                style: _inputTextStyle,
                dropdownColor: Colors.white,
                initialValue: _templateId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Template'),
                items: [
                  for (final t in _classic)
                    DropdownMenuItem(
                      value: t.id,
                      enabled:
                          t.variants.any((variant) => variant.executable) ||
                          t.id == 'germanVolumeTraining',
                      child: Text(t.name),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _templateId = v;
                    _variantId =
                        _template?.variants
                            .where((e) => e.executable)
                            .firstOrNull
                            ?.id ??
                        (_templateId == 'germanVolumeTraining'
                            ? _template?.variants.firstOrNull?.id
                            : null);
                    _syncDays();
                  });
                  _changed();
                },
              ),
              if ((_template?.variants.length ?? 0) > 1)
                const SizedBox(height: 10),
              if ((_template?.variants.length ?? 0) > 1)
                DropdownButtonFormField<String>(
                  key: const Key('variant'),
                  style: _inputTextStyle,
                  dropdownColor: Colors.white,
                  initialValue: _variantId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Variant'),
                  items: [
                    for (final v
                        in _template?.variants.where(
                              (e) =>
                                  e.executable ||
                                  _templateId == 'germanVolumeTraining',
                            ) ??
                            const <CalculatorVariantChoice>[])
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(
                          v.executable ? v.name : '${v.name} · NEEDS_REVIEW',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _variantId = v;
                      _syncDays();
                    });
                    _changed();
                  },
                ),
              if (_variantId == null && _template != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _template!.variants.firstOrNull?.blockedReason ??
                        'Prescription non exécutable.',
                    style: const TextStyle(color: Color(0xfff0f0f0)),
                  ),
                ),
              if (_templateId == 'boringButBig' &&
                  const {
                    'original-5x10',
                    'less-boring',
                  }.contains(_variantId)) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use same ratio for all lifts'),
                  value: _bbbUseSameRatio,
                  onChanged: (value) {
                    setState(() => _bbbUseSameRatio = value);
                    _changed();
                  },
                ),
                if (_bbbUseSameRatio)
                  _percentPicker(
                    'Supplemental',
                    _supplemental,
                    (v) => _supplemental = v,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final lift in _liftIds)
                        SizedBox(
                          width: 150,
                          child: _numberPicker(
                            '${_liftDisplayName(lift)} ratio',
                            _bbbRatiosByLift[lift]!,
                            const [30, 40, 50, 60, 70, 80, 90, 100],
                            (value) => _bbbRatiosByLift[lift] = value,
                            suffix: '%',
                          ),
                        ),
                    ],
                  ),
              ],
              if (_templateId == 'simplestStrength') ...[
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SECONDARY LIFTS',
                    style: TextStyle(
                      color: Color(0xff2c9eff),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'oneRm', label: Text('1 Rep Max')),
                    ButtonSegment(
                      value: 'trainingMax',
                      label: Text('Training Max'),
                    ),
                  ],
                  selected: {_simplestStrengthInput},
                  onSelectionChanged: (values) {
                    setState(() => _simplestStrengthInput = values.first);
                    _changed();
                  },
                ),
                const SizedBox(height: 10),
                for (final lift in _simplestStrengthWeights.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(lift)),
                        if (_simplestStrengthInput == 'oneRm') ...[
                          SizedBox(
                            width: 62,
                            child: TextField(
                              key: ValueKey('simplest-strength-reps-$lift'),
                              controller: _simplestStrengthReps[lift],
                              style: _inputTextStyle,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                suffixText: '×',
                              ),
                              onChanged: (_) => _changed(),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: ValueKey('simplest-strength-weight-$lift'),
                            controller: _simplestStrengthWeights[lift],
                            style: _inputTextStyle,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: _unit,
                            ),
                            onChanged: (_) => _changed(),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  key: const Key('simplest-strength-tm-ratio'),
                  controller: _simplestStrengthRatio,
                  style: _inputTextStyle,
                  enabled: _simplestStrengthInput == 'oneRm',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Training Max Ratio',
                    suffixText: '%',
                  ),
                  onChanged: (_) => _changed(),
                ),
              ],
              if (_templateId == 'bodyweight') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        style: _inputTextStyle,
                        dropdownColor: Colors.white,
                        initialValue: _bodyweightTotalReps,
                        decoration: const InputDecoration(
                          labelText: 'Reps / exercise',
                        ),
                        items: [
                          for (final value in const [50, 75, 100])
                            DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _bodyweightTotalReps = value);
                          _changed();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        style: _inputTextStyle,
                        dropdownColor: Colors.white,
                        initialValue: _bodyweightSetCount,
                        decoration: const InputDecoration(labelText: 'Sets'),
                        items: [
                          for (final value in const [3, 4, 5, 6, 8, 10])
                            DropdownMenuItem(
                              value: value,
                              child: Text('$value'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _bodyweightSetCount = value);
                          _changed();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Your sets will be divided as follows: ${_bodyweightDistribution.join(', ')} reps',
                  textAlign: TextAlign.center,
                ),
              ],
              if (_templateId == 'forBeginners')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Intermediate'),
                  value: _beginnerIntermediate,
                  onChanged: (value) {
                    setState(() => _beginnerIntermediate = value);
                    _changed();
                  },
                ),
              if (_templateId == 'firstSetLast' &&
                  _variantId == 'multiple-sets') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _numberPicker('Set count', _fslSetCount, const [
                        3,
                        4,
                        5,
                      ], (value) => _fslSetCount = value),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _numberPicker(
                        'Repetitions',
                        _fslRepetitions,
                        const [3, 4, 5, 6, 7, 8],
                        (value) => _fslRepetitions = value,
                      ),
                    ),
                  ],
                ),
              ],
              if (_templateId == 'germanVolumeTraining') ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alternate exercise / Less Boring'),
                  value: _gvtAlternateExercise,
                  onChanged: (value) {
                    setState(() => _gvtAlternateExercise = value);
                    _changed();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use same ratio for all lifts'),
                  value: _gvtUseSameRatio,
                  onChanged: (value) {
                    setState(() => _gvtUseSameRatio = value);
                    _changed();
                  },
                ),
                if (_gvtUseSameRatio)
                  _numberPicker(
                    '10 × 10 ratio',
                    _gvtRatio,
                    const [30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
                    (value) => _gvtRatio = value,
                    suffix: '%',
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final lift in _liftIds)
                        SizedBox(
                          width: 150,
                          child: _numberPicker(
                            '${_liftDisplayName(lift)} ratio',
                            _gvtRatiosByLift[lift]!,
                            const [30, 35, 40, 45, 50, 55, 60, 65, 70, 75],
                            (value) => _gvtRatiosByLift[lift] = value,
                            suffix: '%',
                          ),
                        ),
                    ],
                  ),
              ],
            ] else ...[
              DropdownButtonFormField<String>(
                style: _inputTextStyle,
                dropdownColor: Colors.white,
                initialValue: _foreverId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Template Forever exécutable',
                ),
                items: [
                  for (final t in _forever.where((e) => e.executable))
                    DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.name} · ${t.variant}'),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _foreverId = v;
                    _syncDays();
                  });
                  _changed();
                },
              ),
              if (_foreverTemplate != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final step in _foreverTemplate!.sequence)
                        Chip(label: Text(step)),
                    ],
                  ),
                ),
              ],
              if (_forever.where((e) => !e.executable).isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  collapsedIconColor: Colors.white,
                  iconColor: const Color(0xff2c9eff),
                  title: const Text(
                    'Catalogue documentaire',
                    style: TextStyle(color: Colors.white),
                  ),
                  children: [
                    for (final t in _forever.where((e) => !e.executable))
                      ListTile(
                        enabled: false,
                        title: Text(t.name),
                        subtitle: Text(t.blockedReason ?? 'Non exécutable'),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _additional() => _card(
    LayoutBuilder(
      builder: (context, box) {
        final items = [
          _optionColumn('WARMUP', [
            DropdownButtonFormField<String>(
              style: _inputTextStyle,
              dropdownColor: Colors.white,
              initialValue: _warmup,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Option'),
              items: const [
                DropdownMenuItem(value: 'original', child: Text('Original')),
                DropdownMenuItem(value: 'beyond', child: Text('Beyond 5/3/1')),
              ],
              onChanged: (v) {
                setState(() => _warmup = v!);
                _changed();
              },
            ),
            if (_warmup == 'beyond') ...[
              const SizedBox(height: 10),
              Text('Base Weight', style: _label),
              const SizedBox(height: 8),
              TextField(
                key: const Key('warmup-base-lower'),
                controller: _warmupBaseLower,
                style: _inputTextStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Lower Body',
                  suffixText: _unit,
                ),
                onChanged: (_) => _changed(),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('warmup-base-upper'),
                controller: _warmupBaseUpper,
                style: _inputTextStyle,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Upper Body',
                  suffixText: _unit,
                ),
                onChanged: (_) => _changed(),
              ),
            ],
          ]),
          _optionColumn('JOKER SETS', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add Joker Sets'),
              value: _jokers,
              onChanged: (v) {
                setState(() => _jokers = v);
                _changed();
              },
            ),
            if (_jokers)
              _percentPicker(
                'Up to',
                _jokerCap,
                (v) => _jokerCap = v,
                values: const [5, 10, 15, 20, 25, 30],
              ),
          ]),
          _optionColumn('DELOAD', [
            DropdownButtonFormField<String>(
              style: _inputTextStyle,
              dropdownColor: Colors.white,
              initialValue: _deload,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Option'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No deload')),
                DropdownMenuItem(value: 'deload1', child: Text('Deload 1')),
                DropdownMenuItem(value: 'deload2', child: Text('Deload 2')),
                DropdownMenuItem(value: 'deload3', child: Text('Deload 3')),
                DropdownMenuItem(value: 'deload4', child: Text('Deload 4')),
                DropdownMenuItem(value: 'deload5', child: Text('Deload 5')),
                DropdownMenuItem(
                  value: 'highIntensity',
                  child: Text('High intensity'),
                ),
              ],
              onChanged: _mode == 'forever'
                  ? null
                  : (v) {
                      setState(() => _deload = v!);
                      _changed();
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Skip warm-up'),
              value: _skipDeloadWarmup,
              onChanged: _deload == 'none'
                  ? null
                  : (v) {
                      setState(() => _skipDeloadWarmup = v);
                      _changed();
                    },
            ),
          ]),
        ];
        return box.maxWidth > 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(child: item)],
              )
            : Column(children: items);
      },
    ),
  );
  Widget _optionColumn(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff2c9eff),
            fontWeight: FontWeight.w900,
          ),
        ),
        const Divider(),
        ...children,
      ],
    ),
  );
  Widget _percentPicker(
    String label,
    int value,
    void Function(int) assign, {
    List<int> values = const [30, 40, 50, 60, 70],
  }) => DropdownButtonFormField<int>(
    style: _inputTextStyle,
    dropdownColor: Colors.white,
    initialValue: values.contains(value) ? value : values.first,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final v in values) DropdownMenuItem(value: v, child: Text('$v%')),
    ],
    onChanged: (v) {
      setState(() => assign(v!));
      _changed();
    },
  );

  Widget _numberPicker(
    String label,
    int value,
    List<int> values,
    void Function(int) assign, {
    String suffix = '',
  }) => DropdownButtonFormField<int>(
    style: _inputTextStyle,
    dropdownColor: Colors.white,
    initialValue: values.contains(value) ? value : values.first,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final candidate in values)
        DropdownMenuItem(value: candidate, child: Text('$candidate$suffix')),
    ],
    onChanged: (next) {
      if (next == null) return;
      setState(() => assign(next));
      _changed();
    },
  );

  String _liftDisplayName(String lift) => switch (lift) {
    'press' => 'Press',
    'bench' => 'Bench',
    'squat' => 'Squat',
    'deadlift' => 'Deadlift',
    _ => lift,
  };

  Widget _plating() => _card(
    Column(
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 14,
          children: [
            for (final plate in _plateCounts.keys)
              SizedBox(
                width: 130,
                child: Column(
                  children: [
                    Text('$plate $_unit', style: _label),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _plateCounts[plate]! > 0
                              ? () => setState(
                                  () => _plateCounts[plate] =
                                      _plateCounts[plate]! - 1,
                                )
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${_plateCounts[plate]}', style: _label),
                        IconButton(
                          onPressed: () => setState(
                            () =>
                                _plateCounts[plate] = _plateCounts[plate]! + 1,
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bar,
                style: _inputTextStyle,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Barbell weight',
                  suffixText: _unit,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _calculatePlates,
              child: const Text('Calculate'),
            ),
          ],
        ),
        if (_loading != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Per side: ${_loading!.perSide.join(' + ')} $_unit  ·  loaded ${_loading!.actualWeight} $_unit  ·  error ${_loading!.roundingError}',
              style: _label,
            ),
          ),
      ],
    ),
  );

  Widget _scheduling() => _card(
    Column(
      children: [
        if (_allowedDays.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ce template ne possède pas encore de variante exécutable.',
            ),
          )
        else
          SegmentedButton<int>(
            segments: [
              for (final d in _allowedDays)
                ButtonSegment(value: d, label: Text('$d')),
            ],
            selected: {_days},
            onSelectionChanged: (v) {
              setState(() => _days = v.first);
              _changed();
            },
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Lifts order', style: _label),
            const Spacer(),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            for (var i = 0; i < _liftOrder.length; i++)
              DragTarget<String>(
                onAcceptWithDetails: (details) {
                  final from = _liftOrder.indexOf(details.data);
                  if (from == i) return;
                  setState(() {
                    final lift = _liftOrder.removeAt(from);
                    _liftOrder.insert(i, lift);
                  });
                  _changed();
                },
                builder: (context, candidates, rejected) =>
                    LongPressDraggable<String>(
                      data: _liftOrder[i],
                      feedback: Material(
                        color: Colors.transparent,
                        child: Chip(
                          avatar: Icon(
                            _liftIcon(_liftOrder[i]),
                            color: const Color(0xff181818),
                          ),
                          labelStyle: const TextStyle(color: Color(0xff181818)),
                          label: Text(_liftDisplayName(_liftOrder[i])),
                        ),
                      ),
                      child: Chip(
                        avatar: Icon(
                          _liftIcon(_liftOrder[i]),
                          color: const Color(0xff181818),
                        ),
                        labelStyle: const TextStyle(color: Color(0xff181818)),
                        label: Text(
                          '${i + 1}  ${_liftDisplayName(_liftOrder[i])}',
                        ),
                        backgroundColor: candidates.isEmpty
                            ? Colors.white
                            : const Color(0xff9ed4ff),
                      ),
                    ),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bastard work order'),
          subtitle: const Text(
            'Réordonne les séances sans modifier les prescriptions.',
          ),
          value: _bastardWorkOrder,
          onChanged: _mode == 'forever'
              ? null
              : (value) {
                  setState(() => _bastardWorkOrder = value);
                  _changed();
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('3/5/1 week order'),
          value: _weekOrder == '351',
          onChanged: _mode == 'forever'
              ? null
              : (v) {
                  setState(() => _weekOrder = v ? '351' : '531');
                  _changed();
                },
        ),
      ],
    ),
  );
  List<int> get _allowedDays {
    if (_mode == 'forever') return [_foreverTemplate?.days ?? 4];
    final both = {
      ...?_template?.allowedDays,
    }.intersection({...?_variant?.allowedDays});
    return (both.toList()..sort());
  }

  List<int> get _bodyweightDistribution {
    final base = _bodyweightTotalReps ~/ _bodyweightSetCount;
    final remainder = _bodyweightTotalReps % _bodyweightSetCount;
    return List.generate(
      _bodyweightSetCount,
      (index) => base + (index < remainder ? 1 : 0),
    );
  }

  IconData _liftIcon(String id) => switch (id) {
    'press' => Icons.arrow_upward,
    'bench' => Icons.horizontal_rule,
    'squat' => Icons.accessibility_new,
    _ => Icons.fitness_center,
  };

  Widget _outputActions() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('generate-program'),
          onPressed: _busy || _warnings.any((w) => w.isError)
              ? null
              : _generate,
          icon: const Icon(Icons.bolt),
          label: const Text('GENERATE PROGRAM'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _loadExample,
          child: const Text('Charger un exemple'),
        ),
        if (_result != null) ...[
          OutlinedButton.icon(
            key: const Key('export-json'),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: _result!.exportJson)),
            icon: const Icon(Icons.copy),
            label: const Text('COPY JSON'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: _result!.exportJson)),
            icon: const Icon(Icons.share),
            label: const Text('SHARE CONFIGURATION'),
          ),
        ],
      ],
    ),
  );
  Widget _notice(GeneratorWarning w) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: w.isError ? const Color(0xff6d2929) : const Color(0xff4c4320),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(w.message, style: const TextStyle(color: Colors.white)),
    ),
  );

  Widget _program() {
    if (_result == null) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: Text(
              'Renseignez vos charges : le programme apparaît ici.',
              style: TextStyle(color: Color(0xfff0f0f0)),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _result!.title,
          style: const TextStyle(
            color: Color(0xff2c9eff),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_result!.explanation.isNotEmpty)
          Text(
            _result!.explanation,
            style: const TextStyle(color: Colors.white70),
          ),
        const SizedBox(height: 12),
        for (final block in _result!.blocks) ...[
          Text(block.name, style: _label),
          const SizedBox(height: 8),
          for (final week in block.weeks) _weekCard(week),
          const SizedBox(height: 12),
        ],
        if (_result!.sources.isNotEmpty)
          _card(
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Sources & pages',
                style: TextStyle(color: Colors.white),
              ),
              children: [
                for (final s in _result!.sources) ListTile(title: Text(s)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _weekCard(PlanWeekView week) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          week.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xff2c9eff),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final session in week.sessions)
                SizedBox(
                  width: box.maxWidth > 760
                      ? (box.maxWidth -
                                (9 * (week.sessions.length.clamp(1, 4) - 1))) /
                            week.sessions.length.clamp(1, 4)
                      : box.maxWidth > 520
                      ? (box.maxWidth - 9) / 2
                      : box.maxWidth,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xff727272),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          session.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 7),
                        for (final set in session.prescriptions)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xff181818),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              set,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _changed() async {
    final revision = ++_requestRevision;
    await _validate(revision: revision);
    if (revision != _requestRevision) return;
    if (_weights.values.every((c) => (double.tryParse(c.text) ?? 0) > 0) &&
        !_warnings.any((w) => w.isError)) {
      await _generate(validateForm: false, revision: revision);
    } else if (mounted && _busyRevision != null) {
      setState(() {
        _busyRevision = null;
        _busy = false;
      });
    }
  }

  Future<void> _validate({int? revision}) async {
    final w = await widget.core.validate(_configuration);
    if (mounted && (revision == null || revision == _requestRevision)) {
      setState(() => _warnings = w);
    }
  }

  Future<void> _generate({bool validateForm = true, int? revision}) async {
    if (validateForm && !(_form.currentState?.validate() ?? false)) return;
    final activeRevision = revision ?? ++_requestRevision;
    setState(() {
      _busyRevision = activeRevision;
      _busy = true;
    });
    try {
      final r = await widget.core.generate(_configuration);
      if (mounted && activeRevision == _requestRevision) {
        setState(() => _result = r);
      }
    } on Object catch (error) {
      if (mounted && activeRevision == _requestRevision) {
        setState(() => _warnings = [GeneratorWarning('$error', isError: true)]);
      }
    } finally {
      if (mounted && _busyRevision == activeRevision) {
        setState(() {
          _busyRevision = null;
          _busy = false;
        });
      }
    }
  }

  void _syncDays() {
    final allowed = _allowedDays;
    if (allowed.isNotEmpty && !allowed.contains(_days)) _days = allowed.first;
  }

  void _loadExample() {
    const values = [60, 90, 120, 150];
    setState(() {
      _unit = 'kg';
      _input = 'oneRm';
      _ratio.text = '90';
      for (var i = 0; i < _lifts.length; i++) {
        _weights[_lifts[i]]!.text = '${values[i]}';
      }
    });
    _changed();
  }

  void _restore(Map<String, Object?> v) {
    _mode = v['mode'] as String? ?? _mode;
    _foreverId = v['foreverTemplateId'] as String? ?? _foreverId;
    _unit = v['unit'] as String? ?? _unit;
    final old = v['inputMode'];
    _input = switch (old) {
      'Training Max' => 'tm',
      'Rep max' || 'repMax' => 'oneRm',
      '1RM' => 'oneRm',
      String x => x,
      _ => _input,
    };
    final r = v['trainingMaxRatio'];
    if (r is num) _ratio.text = '$r';
    final upperBase = v['warmupBaseUpper'];
    if (upperBase is num) _warmupBaseUpper.text = '$upperBase';
    final lowerBase = v['warmupBaseLower'];
    if (lowerBase is num) _warmupBaseLower.text = '$lowerBase';
    final lv = v['lifts'];
    if (lv is Map) {
      for (final l in _lifts) {
        _weights[l]!.text = '${lv[l] ?? ''}';
      }
    }
    final rp = v['repetitions'];
    if (rp is Map) {
      for (final l in _lifts) {
        _reps[l]!.text = '${rp[l] ?? 1}';
      }
    }
    final pid = v['programId'] as String?;
    if (pid != null) {
      if (_forever.any((e) => e.id == pid)) {
        _mode = 'forever';
        _foreverId = pid;
      } else if (_classic.any((e) => e.id == pid)) {
        _templateId = pid;
        _variantId = _template?.variants.firstOrNull?.id;
      }
    }
    _days = v['days'] as int? ?? _days;
    _syncDays();
  }

  Future<void> _calculatePlates() async {
    final target = double.tryParse(_weights.values.first.text);
    if (target == null) return;
    final inventory = [
      for (final e in _plateCounts.entries)
        for (var i = 0; i < e.value; i++) e.key,
    ];
    final result = await widget.core.calculatePlateLoading(
      weight: target,
      barWeight: double.tryParse(_bar.text) ?? 20,
      inventory: inventory,
      unit: _unit,
    );
    if (mounted) setState(() => _loading = result);
  }
}
