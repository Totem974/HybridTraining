import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/core/platform/browser_route_marker.dart';
import 'package:hybrid_training/features/poc_531/application/forever_series_configuration_repository.dart';

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
    this.planKind = 'macrocycle',
    this.timeline = const [],
    this.days,
    this.blockedReason,
  });
  final String id, name, variant;
  final bool executable;
  final int? days;
  final String? blockedReason;
  final List<String> sequence;
  final String planKind;
  final List<ForeverTimelineNodeChoice> timeline;
}

class ForeverTimelineNodeChoice {
  const ForeverTimelineNodeChoice({
    required this.id,
    required this.title,
    required this.details,
    required this.protocol,
    this.autoInserted = false,
  });

  final String id;
  final String title;
  final List<String> details;
  final bool protocol;
  final bool autoInserted;
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
    this.foreverSeriesRepository,
    this.initialSeriesId,
    super.key,
  });
  final Poc531GeneratorCore core;
  final Map<String, Object?>? initialConfiguration;
  final ForeverSeriesConfigurationRepository? foreverSeriesRepository;
  final String? initialSeriesId;
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
  String _foreverPlanKind = 'macrocycle';
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
  GeneratorWarning? _persistenceWarning;
  GeneratorResult? _result;
  PlateLoadingView? _loading;
  int _requestRevision = 0;
  bool _configurationDirty = false;
  Future<void> _saveQueue = Future<void>.value();
  int? _busyRevision;
  int _foreverStep = 0;
  String _continuationMode = 'repeatSame';
  String _seriesId = 'forever-series-v1';
  bool _seriesTerminated = false;
  List<Map<String, Object?>> _seriesMacrocycles = const [];
  final Map<String, String> _trainingMaxActions = {
    for (final lift in _liftIds) lift: 'applyProposal',
  };
  final Map<String, TextEditingController> _customTrainingMaxes = {
    for (final lift in _liftIds) lift: TextEditingController(),
  };

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
    _foreverId = _forever
        .where(
          (template) =>
              template.executable && template.planKind == _foreverPlanKind,
        )
        .firstOrNull
        ?.id;
    if (widget.initialSeriesId case final seriesId?
        when seriesId.trim().isNotEmpty) {
      _seriesId = seriesId;
    }
    _restore(widget.initialConfiguration ?? const {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markBrowserRouteReady('poc-531-generator');
      _restorePersisted();
    });
  }

  ForeverSeriesConfigurationStore? get _seriesStore =>
      widget.foreverSeriesRepository == null
      ? null
      : ForeverSeriesConfigurationStore(widget.foreverSeriesRepository!);

  Future<void> _restorePersisted() async {
    final store = _seriesStore;
    if (store == null ||
        _foreverPlanKind != 'macrocycle' ||
        (_mode != 'forever' && widget.initialSeriesId == null)) {
      await _validate();
      return;
    }
    final revisionBeforeLoad = _requestRevision;
    try {
      final configuration = await store.load(_seriesId);
      if (!mounted) return;
      if (configuration != null &&
          !_configurationDirty &&
          revisionBeforeLoad == _requestRevision) {
        setState(() {
          _restore(configuration);
          _persistenceWarning = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(
          () => _persistenceWarning = GeneratorWarning(
            _isFrench
                ? 'Impossible de restaurer la série Forever enregistrée.'
                : 'Unable to restore the saved Forever series.',
            isError: true,
          ),
        );
      }
    }
    if (mounted) await _validate();
  }

  @override
  void dispose() {
    for (final c in [
      ..._weights.values,
      ..._reps.values,
      ..._simplestStrengthWeights.values,
      ..._simplestStrengthReps.values,
      ..._customTrainingMaxes.values,
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

  Map<String, Object?> get _legacyConfiguration => {
    'schemaVersion': 2,
    'mode': _mode,
    'unit': _unit,
    'inputMode': _input,
    'trainingMaxRatio': double.tryParse(_ratio.text),
    'templateId': _templateId,
    'variantId': _variantId,
    'foreverTemplateId': _foreverId,
    'days': _days,
    'trainingWeekdays': List.generate(_days, (index) => index + 1),
    'roundingIncrement': _unit == 'lb' ? 5.0 : 2.5,
    'startDate': '2026-01-05',
    'barWeight': double.tryParse(_bar.text),
    'plates': {
      for (final entry in _plateCounts.entries) '${entry.key}': entry.value,
    },
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

  Map<String, Object?> get _configuration {
    final legacy = _legacyConfiguration;
    if (_mode != 'forever') return legacy;
    final common = Map<String, Object?>.from(legacy)
      ..remove('schemaVersion')
      ..remove('mode')
      ..remove('foreverTemplateId');
    return {
      'schemaVersion': 4,
      'mode': 'forever',
      'common': common,
      'forever': _foreverPlanKind == 'standaloneProgram'
          ? {'standaloneProgramId': _foreverId}
          : {
              'series': {
                'id': _seriesId,
                'terminated': _seriesTerminated,
                'macrocycles': _effectiveMacrocycles,
              },
            },
    };
  }

  List<Map<String, Object?>> get _effectiveMacrocycles =>
      _seriesMacrocycles.isEmpty
      ? _seriesTerminated
            ? const []
            : [_newMacrocycle('M1', 'active')]
      : _seriesMacrocycles;

  Map<String, Object?> _newMacrocycle(String id, String status) => {
    'instanceId': id,
    'intent': status == 'planned' ? 'projected' : 'active',
    'status': status,
    'recipeId': 'forever-2l1a-v2',
    'slots': const [
      {
        'slotId': 'leader-1',
        'role': 'leader',
        'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
      },
      {
        'slotId': 'leader-2',
        'role': 'leader',
        'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
      },
      {
        'slotId': 'anchor-1',
        'role': 'anchor',
        'cycleTemplateRevisionId': 'forever-original-pr-set-anchor-v1',
      },
    ],
    'protocols': const [
      {
        'boundaryId': 'leaders-to-anchor',
        'protocolTemplateRevisionId': 'forever-seventh-week-deload-v1',
        'required': true,
      },
      {
        'boundaryId': 'macrocycle-end',
        'protocolTemplateRevisionId': 'forever-seventh-week-tm-test-v1',
        'required': true,
      },
    ],
    'trainingMaxStates': <String, Object?>{},
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
                    const SizedBox(height: 16),
                    _modeSelector(),
                    const SizedBox(height: 24),
                    if (_mode == 'forever')
                      _foreverComposer()
                    else ...[
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
                      if (_warnings.isNotEmpty ||
                          _persistenceWarning != null) ...[
                        const SizedBox(height: 16),
                        if (_persistenceWarning case final warning?)
                          _notice(warning),
                        for (final w in _warnings) _notice(w),
                      ],
                      const SizedBox(height: 26),
                      _heading('PROGRAM'),
                      _program(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  AppStrings get _strings =>
      AppStrings.forLanguage(Localizations.localeOf(context).languageCode);

  bool get _isFrench => _strings.languageCode == 'fr';

  List<String> get _foreverStepLabels => _isFrench
      ? const [
          'Type',
          'Horizon',
          'Architecture',
          'Développement',
          'Ancrage',
          'Protocoles',
          'Options',
          'Résumé',
        ]
      : const [
          'Type',
          'Horizon',
          'Architecture',
          'Leaders',
          'Anchors',
          'Protocols',
          'Options',
          'Summary',
        ];

  Widget _foreverComposer() => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowRight): _nextForeverStep,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousForeverStep,
    },
    child: Focus(
      autofocus: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: _isFrench
                ? 'Composeur Forever, 8 étapes'
                : 'Forever composer, 8 steps',
            child: Wrap(
              key: const Key('forever-eight-stepper'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _foreverStepLabels.length; index++)
                  ChoiceChip(
                    key: ValueKey('forever-step-$index'),
                    selected: index == _foreverStep,
                    label: Text('${index + 1}. ${_foreverStepLabels[index]}'),
                    onSelected: (_) => setState(() => _foreverStep = index),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _foreverStepHelp(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey('forever-step-content-$_foreverStep'),
              child: _foreverStepContent(),
            ),
          ),
          if (_warnings.isNotEmpty || _persistenceWarning != null) ...[
            const SizedBox(height: 16),
            if (_persistenceWarning case final warning?) _notice(warning),
            for (final warning in _warnings) _notice(warning),
          ],
        ],
      ),
    ),
  );

  Widget _foreverStepContent() => switch (_foreverStep) {
    0 => _templatePanel(),
    1 => _foreverMacrocyclePreview(),
    2 =>
      _foreverTemplate == null
          ? const SizedBox.shrink()
          : _foreverTimeline(_foreverTemplate!.timeline),
    3 => _foreverNodeDetails(protocol: false, anchor: false),
    4 => _foreverNodeDetails(protocol: false, anchor: true),
    5 => _foreverNodeDetails(protocol: true),
    6 => LayoutBuilder(
      builder: (context, box) => box.maxWidth >= 700
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _weight()),
                const SizedBox(width: 18),
                Expanded(child: _scheduling()),
              ],
            )
          : Column(
              children: [_weight(), const SizedBox(height: 18), _scheduling()],
            ),
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _foreverMacrocyclePreview(),
        const SizedBox(height: 16),
        _foreverActions(),
        const SizedBox(height: 24),
        _heading(_isFrench ? 'PROGRAMME' : 'PROGRAM'),
        _program(),
      ],
    ),
  };

  Widget _foreverNodeDetails({required bool protocol, bool? anchor}) {
    final nodes =
        _foreverTemplate?.timeline.where((node) {
          if (node.protocol != protocol) return false;
          if (protocol || anchor == null) return true;
          return node.title.toLowerCase().contains('anchor') == anchor;
        }).toList() ??
        const <ForeverTimelineNodeChoice>[];
    return nodes.isEmpty
        ? _card(
            Text(
              _isFrench ? 'Aucun élément disponible.' : 'No item available.',
            ),
          )
        : _foreverTimeline(nodes);
  }

  Widget _foreverStepHelp() => _card(
    Row(
      children: [
        IconButton(
          key: const Key('forever-step-previous'),
          tooltip: _isFrench ? 'Étape précédente' : 'Previous step',
          onPressed: _foreverStep == 0 ? null : _previousForeverStep,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: Text(
            _foreverStepDescription(_foreverStep),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          key: const Key('forever-step-next'),
          tooltip: _isFrench ? 'Étape suivante' : 'Next step',
          onPressed: _foreverStep == 7 ? null : _nextForeverStep,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    ),
  );

  String _foreverStepDescription(int step) {
    final fr = _isFrench;
    return switch (step) {
      0 => fr ? 'Choisissez le type de plan.' : 'Choose the plan type.',
      1 =>
        fr
            ? 'Un macrocycle est généré à la fois.'
            : 'One macrocycle is generated at a time.',
      2 =>
        fr
            ? 'Vérifiez la séquence complète avant génération.'
            : 'Review the complete sequence before generation.',
      3 => fr ? 'C2 reprend C1 par défaut.' : 'C2 uses C1 by default.',
      4 => fr ? 'Vérifiez le bloc d’ancrage.' : 'Review the Anchor block.',
      5 =>
        fr
            ? 'Les protocoles obligatoires sont verrouillés.'
            : 'Required protocols are locked.',
      6 =>
        fr
            ? 'Réglez uniquement les options disponibles.'
            : 'Set only the available options.',
      _ =>
        fr
            ? 'Contrôlez le résumé puis générez le programme.'
            : 'Review the summary, then generate the program.',
    };
  }

  void _nextForeverStep() =>
      setState(() => _foreverStep = (_foreverStep + 1).clamp(0, 7));

  void _previousForeverStep() =>
      setState(() => _foreverStep = (_foreverStep - 1).clamp(0, 7));

  Widget _foreverMacrocyclePreview() => Semantics(
    label: _isFrench ? 'Horizon des macrocycles' : 'Macrocycle horizon',
    child: LayoutBuilder(
      builder: (context, box) {
        final actual = _effectiveMacrocycles;
        final cards = <Widget>[
          for (final macrocycle in actual)
            _macrocycleCard(macrocycle, materialized: true),
          for (var index = actual.length; index < 3; index++)
            _macrocycleCard({
              'instanceId': 'M${index + 1}',
              'status': 'preview',
            }, materialized: false),
        ];
        return box.maxWidth >= 620
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(child: cards[index]),
                  ],
                ],
              )
            : Column(
                children: [
                  for (final card in cards) ...[
                    card,
                    const SizedBox(height: 8),
                  ],
                ],
              );
      },
    ),
  );

  String _macrocycleStatus(String status) => switch (status) {
    'completed' => _isFrench ? 'Terminé' : 'Completed',
    'cancelled' => _isFrench ? 'Annulé' : 'Cancelled',
    'planned' || 'preview' => _isFrench ? 'Projeté' : 'Projected',
    _ => _isFrench ? 'Actif' : 'Active',
  };

  Widget _macrocycleCard(
    Map<String, Object?> macrocycle, {
    required bool materialized,
  }) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${macrocycle['instanceId']} · '
          '${_macrocycleStatus('${macrocycle['status']}')}',
          style: _label,
        ),
        const SizedBox(height: 6),
        Text(
          materialized
              ? (_foreverTemplate?.sequence.join(' → ') ?? '—')
              : (_isFrench
                    ? 'Aperçu uniquement · non matérialisé'
                    : 'Preview only · not materialized'),
          style: const TextStyle(color: Colors.white70),
        ),
        if (materialized) ...[
          const SizedBox(height: 6),
          Text(
            '${_isFrench ? 'Recette' : 'Recipe'}: '
            '${macrocycle['recipeId'] ?? '—'}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            _isFrench
                ? 'Rôles : développement ×2 · ancrage ×1'
                : 'Roles: Leader ×2 · Anchor ×1',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            _isFrench
                ? 'Protocoles : semaine 7 de récupération · test du maximum d’entraînement'
                : 'Protocols: 7th Week Deload · Training Max Test',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            '${_isFrench ? 'Décisions TM' : 'TM decisions'}: '
            '${(macrocycle['trainingMaxStates'] as Map?)?.length ?? 0}/4',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ],
    ),
  );

  Widget _foreverActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(_isFrench ? 'CONTINUATION' : 'CONTINUATION'),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isFrench
                  ? 'Après M1, choisissez une action pour le futur. Le macrocycle terminé reste inchangé.'
                  : 'After M1, choose an action for the future. The completed macrocycle stays unchanged.',
            ),
            if (_activeMacrocycle != null) ...[
              const SizedBox(height: 12),
              Text(
                _isFrench
                    ? 'Décision Training Max par mouvement'
                    : 'Training Max decision by lift',
                style: _label,
              ),
              const SizedBox(height: 8),
              for (final lift in _liftIds) _trainingMaxControl(lift),
              FilledButton.icon(
                key: const Key('complete-active-macrocycle'),
                onPressed: _trainingMaxDecisionsAreValid
                    ? _completeActiveMacrocycle
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  _isFrench
                      ? 'Terminer le macrocycle actif'
                      : 'Complete active macrocycle',
                ),
              ),
            ],
            if (_activeMacrocycle == null && _nextPlannedMacrocycle != null)
              FilledButton.icon(
                key: const Key('activate-next-macrocycle'),
                onPressed: _activateNextMacrocycle,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  _isFrench
                      ? 'Démarrer le prochain macrocycle'
                      : 'Start next macrocycle',
                ),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const Key('continuation-mode'),
              initialValue: _continuationMode,
              style: _inputTextStyle,
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                labelText: _isFrench
                    ? 'Mode de continuation'
                    : 'Continuation mode',
              ),
              items: [
                for (final mode in const [
                  'manual',
                  'repeatSame',
                  'cloneAndEdit',
                  'recommendNext',
                ])
                  DropdownMenuItem(
                    value: mode,
                    child: Text(_continuationLabel(mode)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _markDirty();
                  setState(() => _continuationMode = value);
                }
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('continue-next-macrocycle'),
              onPressed: _canAppendMacrocycle ? _appendMacrocycle : null,
              icon: const Icon(Icons.add),
              label: Text(
                _isFrench
                    ? 'Ajouter le macrocycle suivant'
                    : 'Add next macrocycle',
              ),
            ),
            Text(
              _isFrench
                  ? (_canAppendMacrocycle
                        ? 'Le prochain macrocycle sera ajouté sans modifier l’historique.'
                        : 'Disponible une fois le macrocycle actif terminé.')
                  : (_canAppendMacrocycle
                        ? 'The next macrocycle will be added without changing history.'
                        : 'Available once the active macrocycle is complete.'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('terminate-forever-series'),
              onPressed: _seriesTerminated || _activeMacrocycle != null
                  ? null
                  : _terminateSeries,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(_isFrench ? 'Terminer la série' : 'End series'),
            ),
            const SizedBox(height: 12),
            _outputActions(),
          ],
        ),
      ),
    ],
  );

  bool get _canAppendMacrocycle =>
      !_seriesTerminated &&
      _effectiveMacrocycles.isNotEmpty &&
      _effectiveMacrocycles.last['status'] == 'completed';

  Map<String, Object?>? get _activeMacrocycle => _effectiveMacrocycles
      .where((macrocycle) => macrocycle['status'] == 'active')
      .firstOrNull;

  Map<String, Object?>? get _nextPlannedMacrocycle => _effectiveMacrocycles
      .where((macrocycle) => macrocycle['status'] == 'planned')
      .firstOrNull;

  Widget _trainingMaxControl(String lift) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('tm-decision-$lift'),
          initialValue: _trainingMaxActions[lift],
          isExpanded: true,
          style: _inputTextStyle,
          dropdownColor: Colors.white,
          decoration: InputDecoration(labelText: _liftDisplayName(lift)),
          items: [
            for (final action in const [
              'applyProposal',
              'customProposal',
              'hold',
              'reset',
            ])
              DropdownMenuItem(
                value: action,
                child: Text(_trainingMaxActionLabel(action)),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _markDirty();
            setState(() {
              _trainingMaxActions[lift] = value;
              if (value == 'customProposal' &&
                  _customTrainingMaxes[lift]!.text.isEmpty) {
                _customTrainingMaxes[lift]!.text = _formatTrainingMax(
                  _currentTrainingMax(lift),
                );
              }
            });
          },
        ),
        if (_trainingMaxActions[lift] == 'customProposal') ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('tm-custom-$lift'),
            controller: _customTrainingMaxes[lift],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _inputTextStyle,
            decoration: InputDecoration(
              labelText: _isFrench ? 'TM choisi' : 'Chosen TM',
              helperText: _isFrench
                  ? 'Entre ${_formatTrainingMax(_currentTrainingMax(lift))} et ${_formatTrainingMax(_proposedTrainingMax(lift))}'
                  : 'Between ${_formatTrainingMax(_currentTrainingMax(lift))} and ${_formatTrainingMax(_proposedTrainingMax(lift))}',
              errorText: _customTrainingMaxIsValid(lift)
                  ? null
                  : (_isFrench
                        ? 'Saisissez une valeur dans cet intervalle.'
                        : 'Enter a value within this range.'),
            ),
            onChanged: (_) {
              _markDirty();
              setState(() {});
            },
          ),
        ],
      ],
    ),
  );

  String _trainingMaxActionLabel(String action) =>
      switch ((action, _isFrench)) {
        ('applyProposal', true) => 'Appliquer la proposition',
        ('customProposal', true) => 'Choisir une valeur',
        ('hold', true) => 'Maintenir',
        ('reset', true) => 'Réinitialiser au TM saisi',
        ('applyProposal', false) => 'Apply proposal',
        ('customProposal', false) => 'Choose a value',
        ('hold', false) => 'Hold',
        _ => 'Reset to entered TM',
      };

  double _currentTrainingMax(String lift) {
    final active = _activeMacrocycle;
    if (active != null) {
      final activeIndex = _effectiveMacrocycles.indexWhere(
        (macrocycle) => macrocycle['instanceId'] == active['instanceId'],
      );
      for (var index = activeIndex - 1; index >= 0; index--) {
        final states = _effectiveMacrocycles[index]['trainingMaxStates'];
        final state = states is Map ? states[lift] : null;
        final inherited = state is Map ? state['trainingMax'] : null;
        if (inherited is num) return inherited.toDouble();
      }
    }
    return _enteredTrainingMax(lift);
  }

  double _enteredTrainingMax(String lift) {
    final name = switch (lift) {
      'press' => 'Press',
      'bench' => 'Bench Press',
      'squat' => 'Squat',
      _ => 'Deadlift',
    };
    final entered = double.tryParse(_weights[name]!.text) ?? 0;
    return _input == 'tm'
        ? entered
        : entered * ((double.tryParse(_ratio.text) ?? 90) / 100);
  }

  double _progressionIncrement(String lift) =>
      lift == 'press' || lift == 'bench' ? 2.5 : 5;

  double _proposedTrainingMax(String lift) =>
      _currentTrainingMax(lift) + _progressionIncrement(lift);

  String _formatTrainingMax(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  bool _customTrainingMaxIsValid(String lift) {
    final value = _parseLocalizedNumber(_customTrainingMaxes[lift]!.text);
    return value != null &&
        value >= _currentTrainingMax(lift) &&
        value <= _proposedTrainingMax(lift);
  }

  double? _parseLocalizedNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  bool get _trainingMaxDecisionsAreValid => _liftIds.every(
    (lift) =>
        _trainingMaxActions[lift] != 'customProposal' ||
        _customTrainingMaxIsValid(lift),
  );

  void _completeActiveMacrocycle() {
    final active = _activeMacrocycle;
    if (active == null) return;
    final activeId = active['instanceId'];
    final completed = <Map<String, Object?>>[
      for (final macrocycle in _effectiveMacrocycles)
        if (macrocycle['instanceId'] != activeId)
          Map<String, Object?>.from(macrocycle)
        else
          {
            ...macrocycle,
            'status': 'completed',
            'trainingMaxStates': {
              for (final lift in _liftIds) lift: _trainingMaxState(lift),
            },
          },
    ];
    setState(() => _seriesMacrocycles = completed);
    _changed();
  }

  Map<String, Object?> _trainingMaxState(String lift) {
    final current = _currentTrainingMax(lift);
    return switch (_trainingMaxActions[lift]) {
      'customProposal' => {
        'state': 'confirmed',
        'trainingMax': _parseLocalizedNumber(_customTrainingMaxes[lift]!.text)!,
      },
      'hold' => {'state': 'held', 'trainingMax': current},
      'reset' => {'state': 'reset', 'trainingMax': _enteredTrainingMax(lift)},
      _ => {'state': 'confirmed', 'trainingMax': _proposedTrainingMax(lift)},
    };
  }

  String _continuationLabel(String mode) => switch ((mode, _isFrench)) {
    ('manual', true) => 'Manuel',
    ('repeatSame', true) => 'Répéter à l’identique',
    ('cloneAndEdit', true) => 'Cloner puis modifier',
    ('recommendNext', true) => 'Recommander la suite',
    ('manual', false) => 'Manual',
    ('repeatSame', false) => 'Repeat same',
    ('cloneAndEdit', false) => 'Clone and edit',
    _ => 'Recommend next',
  };

  void _appendMacrocycle() {
    if (!_canAppendMacrocycle) return;
    final preserved = [
      for (final macrocycle in _effectiveMacrocycles)
        Map<String, Object?>.from(macrocycle),
    ];
    final completed = preserved.last;
    final nextId = 'M${preserved.length + 1}';
    final next = switch (_continuationMode) {
      'repeatSame' || 'cloneAndEdit' => <String, Object?>{
        ..._newMacrocycle(nextId, 'planned'),
        'recipeId': completed['recipeId'],
        'slots': completed['slots'],
        'protocols': completed['protocols'],
        'continuationMode': _continuationMode,
      },
      _ => {
        ..._newMacrocycle(nextId, 'planned'),
        'continuationMode': _continuationMode,
      },
    };
    setState(() => _seriesMacrocycles = [...preserved, next]);
    _changed();
  }

  void _activateNextMacrocycle() {
    final planned = _nextPlannedMacrocycle;
    if (planned == null) return;
    final plannedId = planned['instanceId'];
    setState(() {
      _trainingMaxActions
        ..clear()
        ..addAll({for (final lift in _liftIds) lift: 'applyProposal'});
      for (final controller in _customTrainingMaxes.values) {
        controller.clear();
      }
      _seriesMacrocycles = [
        for (final macrocycle in _effectiveMacrocycles)
          if (macrocycle['instanceId'] == plannedId)
            {...macrocycle, 'intent': 'active', 'status': 'active'}
          else
            Map<String, Object?>.from(macrocycle),
      ];
    });
    _changed();
  }

  void _terminateSeries() {
    setState(() {
      _seriesTerminated = true;
      _seriesMacrocycles = [
        for (final macrocycle in _effectiveMacrocycles)
          if (macrocycle['intent'] != 'projected')
            Map<String, Object?>.from(macrocycle),
      ];
    });
    _changed();
  }

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

  Widget _modeSelector() => Semantics(
    label: 'Mode de programmation',
    container: true,
    child: _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            key: const Key('planning-mode-selector'),
            segments: [
              const ButtonSegment(
                value: 'classic',
                label: Text('Cycle 5/3/1'),
                tooltip: 'Original, Beyond et extensions',
              ),
              ButtonSegment(
                value: 'forever',
                label: const Text('Forever'),
                tooltip: _isFrench
                    ? 'Développement, ancrage et macrocycles'
                    : 'Leaders, Anchors and macrocycles',
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (values) => _switchMode(values.first),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == 'classic'
                ? 'Original, Beyond et extensions'
                : (_isFrench
                      ? 'Développement, ancrage et macrocycles'
                      : 'Leaders, Anchors and macrocycles'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffd8d8d8)),
          ),
        ],
      ),
    ),
  );

  void _switchMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _result = null;
      _warnings = const [];
      _syncDays();
    });
    SystemNavigator.routeInformationUpdated(
      uri: Uri(
        path: '/poc/531/generator',
        queryParameters: {'mode': mode == 'classic' ? 'cycle' : 'forever'},
      ),
      replace: true,
    );
    _changed();
  }

  Widget _foreverTimeline(List<ForeverTimelineNodeChoice> nodes) => Semantics(
    label: _isFrench ? 'Chronologie Forever' : 'Forever timeline',
    child: Column(
      key: const Key('forever-timeline'),
      children: [
        for (final node in nodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: node.protocol
                  ? const Color(0xff24405a)
                  : const Color(0xff454545),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xff2c9eff),
                  foregroundColor: const Color(0xff181818),
                  child: Text(node.id),
                ),
                title: Text(_localizedForeverText(node.title)),
                subtitle: Text(
                  node.details.map(_localizedForeverText).join(' · '),
                ),
                trailing: node.autoInserted
                    ? Tooltip(
                        message: _isFrench
                            ? 'Protocole obligatoire inséré par le moteur'
                            : 'Required protocol inserted by the engine',
                        child: const Icon(Icons.lock_outline),
                      )
                    : const Icon(Icons.check_circle_outline),
              ),
            ),
          ),
      ],
    ),
  );

  String _localizedForeverText(String value) {
    if (!_isFrench) return value;
    return value
        .replaceAll(
          '7th Week Training Max Test',
          'Test du maximum d’entraînement de la 7e semaine',
        )
        .replaceAll('7th Week Deload', 'Semaine 7 de récupération')
        .replaceAll('Training Max Test', 'Test du maximum d’entraînement')
        .replaceAll('Leader', 'Développement')
        .replaceAll('Anchor', 'Ancrage');
  }

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
              SegmentedButton<String>(
                key: const Key('forever-plan-kind'),
                segments: const [
                  ButtonSegment(
                    value: 'standaloneProgram',
                    label: Text('Programme autonome'),
                  ),
                  ButtonSegment(
                    value: 'macrocycle',
                    label: Text('Construire un macrocycle'),
                  ),
                ],
                selected: {_foreverPlanKind},
                onSelectionChanged: (values) {
                  final kind = values.first;
                  setState(() {
                    _foreverPlanKind = kind;
                    _foreverId = _forever
                        .where(
                          (template) =>
                              template.executable &&
                              template.planKind == _foreverPlanKind,
                        )
                        .firstOrNull
                        ?.id;
                    _syncDays();
                    _result = null;
                  });
                  _changed();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                style: _inputTextStyle,
                dropdownColor: Colors.white,
                initialValue: _foreverId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Template Forever exécutable',
                ),
                items: [
                  for (final t in _forever.where(
                    (e) => e.executable && e.planKind == _foreverPlanKind,
                  ))
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
                if (_foreverTemplate!.timeline.isEmpty)
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
                  )
                else
                  _foreverTimeline(_foreverTemplate!.timeline),
                if (_foreverPlanKind == 'macrocycle') ...[
                  const SizedBox(height: 10),
                  const CheckboxListTile(
                    value: false,
                    onChanged: null,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Utiliser un autre Leader pour C2'),
                    subtitle: Text(
                      'Aucun autre Leader compatible et sourcé n’est disponible.',
                    ),
                  ),
                ],
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
        Wrap(
          spacing: 4,
          children: [
            for (var i = 0; i < _liftOrder.length; i++)
              Semantics(
                label: 'Réordonner ${_liftDisplayName(_liftOrder[i])}',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Monter ${_liftDisplayName(_liftOrder[i])}',
                      onPressed: i == 0 ? null : () => _moveLift(i, i - 1),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton(
                      tooltip: 'Descendre ${_liftDisplayName(_liftOrder[i])}',
                      onPressed: i == _liftOrder.length - 1
                          ? null
                          : () => _moveLift(i, i + 1),
                      icon: const Icon(Icons.arrow_forward),
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

  void _moveLift(int from, int to) {
    setState(() {
      final lift = _liftOrder.removeAt(from);
      _liftOrder.insert(to, lift);
    });
    _changed();
  }

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
        OutlinedButton.icon(
          key: const Key('share-configuration'),
          onPressed: _shareConfiguration,
          icon: const Icon(Icons.share),
          label: const Text('SHARE CONFIGURATION'),
        ),
        if (_result != null) ...[
          OutlinedButton.icon(
            key: const Key('export-json'),
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: _result!.exportJson)),
            icon: const Icon(Icons.copy),
            label: const Text('COPY JSON'),
          ),
        ],
      ],
    ),
  );

  Future<void> _shareConfiguration() async {
    final payload = await widget.core.serializeConfiguration(_configuration);
    final link = Uri(
      path: '/poc/531/generator',
      queryParameters: {
        'mode': _mode == 'classic' ? 'cycle' : 'forever',
        'configuration': payload,
      },
    );
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien de configuration v3 copié.')),
    );
  }

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
    _configurationDirty = true;
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
    final form = _form.currentState;
    if (validateForm && form != null && !form.validate()) return;
    final activeRevision = revision ?? ++_requestRevision;
    setState(() {
      _busyRevision = activeRevision;
      _busy = true;
    });
    try {
      final configuration = _configuration;
      final r = await widget.core.generate(configuration);
      if (mounted && activeRevision == _requestRevision) {
        setState(() => _result = r);
        if (configuration['schemaVersion'] == 4) {
          await _savePersisted(configuration, activeRevision);
        }
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

  Future<void> _savePersisted(
    Map<String, Object?> configuration,
    int revision,
  ) {
    final store = _seriesStore;
    if (store == null) return Future<void>.value();
    final snapshot = _copyConfiguration(configuration);
    final operation = _saveQueue.then((_) async {
      try {
        await store.save(_seriesId, snapshot);
        if (mounted && revision == _requestRevision) {
          setState(() => _persistenceWarning = null);
        }
      } on Object {
        if (mounted && revision == _requestRevision) {
          setState(
            () => _persistenceWarning = GeneratorWarning(
              _isFrench
                  ? 'Impossible d’enregistrer la série Forever.'
                  : 'Unable to save the Forever series.',
              isError: true,
            ),
          );
        }
      }
    });
    _saveQueue = operation;
    return operation;
  }

  void _markDirty() {
    _configurationDirty = true;
    _requestRevision++;
  }

  Map<String, Object?> _copyConfiguration(Map<String, Object?> source) => {
    for (final entry in source.entries)
      entry.key: switch (entry.value) {
        Map value => _copyConfiguration(Map<String, Object?>.from(value)),
        List value => [for (final item in value) _copyConfigurationValue(item)],
        final value => value,
      },
  };

  Object? _copyConfigurationValue(Object? value) => switch (value) {
    Map map => _copyConfiguration(Map<String, Object?>.from(map)),
    List list => [for (final item in list) _copyConfigurationValue(item)],
    _ => value,
  };

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
    if (v['schemaVersion'] == 4 && v['common'] is Map) {
      final common = Map<String, Object?>.from(v['common']! as Map);
      final forever = v['forever'];
      if (v['mode'] == 'forever' && forever is Map) {
        final standalone = forever['standaloneProgramId'];
        if (standalone is String) {
          _foreverPlanKind = 'standaloneProgram';
          _foreverId = standalone;
        } else if (forever['series'] is Map) {
          final series = forever['series']! as Map;
          final restoredSeriesId = series['id'];
          if (restoredSeriesId is String && restoredSeriesId.isNotEmpty) {
            _seriesId = restoredSeriesId;
          }
          _seriesTerminated = series['terminated'] == true;
          final rawMacrocycles = series['macrocycles'];
          if (rawMacrocycles is List) {
            _seriesMacrocycles = [
              for (final value in rawMacrocycles.whereType<Map>())
                Map<String, Object?>.from(value),
            ];
          }
          _foreverPlanKind = 'macrocycle';
          _foreverId = _forever
              .where((template) => template.planKind == 'macrocycle')
              .firstOrNull
              ?.id;
        }
      }
      _restore({
        ...common,
        'schemaVersion': 2,
        'mode': v['mode'],
        'foreverTemplateId': _foreverId,
      });
      return;
    }
    if (v['schemaVersion'] == 3 && v['common'] is Map) {
      final common = Map<String, Object?>.from(v['common']! as Map);
      final branch = v[v['mode'] == 'forever' ? 'forever' : 'cycle'];
      _restore({
        ...common,
        if (branch is Map) ...Map<String, Object?>.from(branch),
        'schemaVersion': 2,
        'mode': v['mode'],
        if (branch is Map && branch['programId'] != null)
          'foreverTemplateId': branch['programId'],
      });
      return;
    }
    final restoredMode = v['mode'];
    if (restoredMode == 'cycle' || restoredMode == 'classic') {
      _mode = 'classic';
    } else if (restoredMode == 'forever') {
      _mode = 'forever';
    }
    final restoredForeverId = v['foreverTemplateId'];
    if (restoredForeverId is String &&
        _forever.any((template) => template.id == restoredForeverId)) {
      _foreverId = restoredForeverId;
    }
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
    final barWeight = v['barWeight'];
    if (barWeight is num) _bar.text = '$barWeight';
    final plates = v['plates'];
    if (plates is Map) {
      for (final plate in _plateCounts.keys) {
        final count = plates['$plate'];
        if (count is int) _plateCounts[plate] = count;
      }
    }
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
    final restoredTemplateId = v['templateId'];
    if (restoredTemplateId is String &&
        _classic.any((template) => template.id == restoredTemplateId)) {
      _templateId = restoredTemplateId;
    }
    final restoredVariantId = v['variantId'];
    if (restoredVariantId is String &&
        (_template?.variants.any(
              (variant) => variant.id == restoredVariantId,
            ) ??
            false)) {
      _variantId = restoredVariantId;
    }
    _foreverPlanKind = _foreverTemplate?.planKind ?? _foreverPlanKind;
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
