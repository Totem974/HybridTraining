import 'models.dart';

const _standard = CalculatorSource('5/3/1 — Second Edition', 'PDF 28-31');
const _bbb = CalculatorSource('Beyond 5/3/1', 'PDF 29-42');
const _pyramid = CalculatorSource('Beyond 5/3/1', 'PDF 18-19');
const _fsl = CalculatorSource('Beyond 5/3/1', 'PDF 20-21');
const _fives = CalculatorSource('Beyond 5/3/1', 'PDF 83-84');
const _audit = CalculatorSource(
  'Original application black-box audit',
  'E003, E025-E027, E031',
);
const _originalAssistance = CalculatorSource(
  '5/3/1 — Second Edition',
  'PDF 64-77',
);
const _originalSchedules = CalculatorSource(
  '5/3/1 — Second Edition',
  'PDF 99-118',
);
const _gvt = CalculatorSource('Beyond 5/3/1', 'PDF 45-48');

const calculatorTemplates = <TemplateDefinition>[
  TemplateDefinition(
    id: CalculatorTemplateId.standard,
    label: '5/3/1',
    allowedDays: {3, 4},
    sources: [_standard],
    variants: [
      VariantDefinition(
        id: 'standard',
        label: 'Standard',
        status: EvidenceStatus.executable,
        sources: [_standard],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.boringButBig,
    label: 'Boring But Big',
    allowedDays: {2, 3, 4},
    sources: [_bbb],
    variants: [
      VariantDefinition(
        id: 'original-5x10',
        label: 'Original (5x10)',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: 'less-boring',
        label: 'Less Boring',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: '5x5',
        label: '5x5',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: '5x3',
        label: '5x3',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: '5x1',
        label: '5x1',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: 'beyond-variation-1',
        label: 'Beyond Variation 1',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: 'beyond-variation-2',
        label: 'Beyond Variation 2',
        status: EvidenceStatus.executable,
        sources: [_bbb],
      ),
      VariantDefinition(
        id: 'two-days',
        label: '2 Days/Week',
        status: EvidenceStatus.executable,
        allowedDays: {2},
        sources: [_bbb],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.triumvirate,
    label: 'Triumvirate',
    allowedDays: {3, 4},
    sources: [_originalAssistance],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.executable,
        sources: [_originalAssistance],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.periodizationBible,
    label: 'Periodization Bible',
    allowedDays: {3, 4},
    sources: [_originalAssistance],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.executable,
        sources: [_originalAssistance],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.bodyweight,
    label: 'Bodyweight',
    allowedDays: {3, 4},
    sources: [_originalAssistance],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.executable,
        sources: [_originalAssistance],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.simplestStrength,
    label: 'Simplest Strength',
    allowedDays: {3, 4},
    sources: [_originalAssistance],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.executable,
        sources: [_originalAssistance],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.forBeginners,
    label: 'For Beginners',
    allowedDays: {3},
    sources: [_originalSchedules],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.executable,
        allowedDays: {3},
        sources: [_originalSchedules],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.fullBody,
    label: 'Full Body',
    allowedDays: {3},
    sources: [_originalSchedules],
    variants: [
      VariantDefinition(
        id: 'phase-1',
        label: 'Phase 1',
        status: EvidenceStatus.needsReview,
        allowedDays: {3},
        sources: [_originalSchedules],
        blockedReason:
            'La prescription Full Body multi-lifts doit être représentée explicitement.',
      ),
      VariantDefinition(
        id: 'phase-2',
        label: 'Phase 2',
        status: EvidenceStatus.needsReview,
        allowedDays: {3},
        sources: [_originalSchedules],
        blockedReason:
            'La prescription Full Body multi-lifts doit être représentée explicitement.',
      ),
      VariantDefinition(
        id: 'phase-3',
        label: 'Phase 3',
        status: EvidenceStatus.needsReview,
        allowedDays: {3},
        sources: [_originalSchedules],
        blockedReason:
            'La prescription Full Body multi-lifts doit être représentée explicitement.',
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.twoDaysPerWeek,
    label: '2 Days / Week',
    allowedDays: {2},
    sources: [_originalSchedules],
    variants: [
      VariantDefinition(
        id: 'original',
        label: 'Original',
        status: EvidenceStatus.needsReview,
        allowedDays: {2},
        sources: [_originalSchedules],
        blockedReason:
            'Le regroupement de deux lifts par séance requiert un modèle de planning dédié.',
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.pyramid,
    label: 'Pyramid',
    allowedDays: {3, 4},
    sources: [_pyramid],
    variants: [
      VariantDefinition(
        id: 'pyramid',
        label: 'Pyramid',
        status: EvidenceStatus.executable,
        sources: [_pyramid],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.firstSetLast,
    label: 'First Set Last',
    allowedDays: {3, 4},
    sources: [_fsl, _audit],
    variants: [
      VariantDefinition(
        id: 'amrap',
        label: 'AMRAP',
        status: EvidenceStatus.executable,
        sources: [_fsl, _audit],
      ),
      VariantDefinition(
        id: 'multiple-sets',
        label: 'Multiple Sets',
        status: EvidenceStatus.executable,
        sources: [_fsl],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.germanVolumeTraining,
    label: 'German Volume Training',
    allowedDays: {4},
    sources: [_gvt],
    variants: [
      VariantDefinition(
        id: '10x10',
        label: '10×10',
        status: EvidenceStatus.executable,
        sources: [_gvt],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.fivesProgression,
    label: "5's Progression",
    allowedDays: {3, 4},
    sources: [_fives],
    variants: [
      VariantDefinition(
        id: 'fives-progression',
        label: "5's Progression",
        status: EvidenceStatus.executable,
        sources: [_fives],
      ),
    ],
  ),
  TemplateDefinition(
    id: CalculatorTemplateId.boringButBigChallenge,
    label: 'Boring But Big Challenge',
    allowedDays: {4},
    sources: [_bbb],
    variants: [
      VariantDefinition(
        id: 'six-week',
        label: '6 Week Challenge',
        status: EvidenceStatus.needsReview,
        sources: [_bbb],
        blockedReason:
            'Le cycle de six semaines et sa progression de Training Max doivent être modélisés ensemble.',
      ),
      VariantDefinition(
        id: 'three-month',
        label: '3 Month Challenge',
        status: EvidenceStatus.needsReview,
        sources: [_bbb],
        blockedReason:
            'Le challenge de trois mois requiert un modèle multi-cycle avec progression de Training Max.',
      ),
      VariantDefinition(
        id: 'thirteen-week',
        label: '13 Week Challenge',
        status: EvidenceStatus.needsReview,
        sources: [_bbb],
        blockedReason:
            'Le challenge de treize semaines requiert un modèle multi-cycle avec progression de Training Max.',
      ),
    ],
  ),
];

TemplateDefinition calculatorTemplate(CalculatorTemplateId id) =>
    calculatorTemplates.firstWhere((value) => value.id == id);
