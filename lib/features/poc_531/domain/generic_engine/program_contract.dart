import 'dart:collection';

import 'catalog_contract.dart';
import 'engine_contract.dart';

enum ProgramPhaseRole {
  preparation,
  leader,
  anchor,
  realization,
  recovery,
  custom,
}

enum TrainingMaxTransitionKind { keep, add, multiply, testThenSet }

final class TrainingMaxTransition {
  TrainingMaxTransition._(
    this.kind, {
    this.upperDelta,
    this.lowerDelta,
    this.ratio,
  });
  factory TrainingMaxTransition.keep() =>
      TrainingMaxTransition._(TrainingMaxTransitionKind.keep);
  factory TrainingMaxTransition.add({
    required double upperDelta,
    required double lowerDelta,
  }) {
    if (upperDelta <= 0 || lowerDelta <= 0) {
      throw ArgumentError('TM deltas must be positive.');
    }
    return TrainingMaxTransition._(
      TrainingMaxTransitionKind.add,
      upperDelta: upperDelta,
      lowerDelta: lowerDelta,
    );
  }
  factory TrainingMaxTransition.multiply(double ratio) {
    if (ratio <= 0 || ratio > 1) {
      throw ArgumentError.value(ratio, 'ratio');
    }
    return TrainingMaxTransition._(
      TrainingMaxTransitionKind.multiply,
      ratio: ratio,
    );
  }
  factory TrainingMaxTransition.testThenSet() =>
      TrainingMaxTransition._(TrainingMaxTransitionKind.testThenSet);
  final TrainingMaxTransitionKind kind;
  final double? upperDelta;
  final double? lowerDelta;
  final double? ratio;
}

final class ProgramSegment {
  ProgramSegment({
    required this.id,
    required this.templateId,
    required this.templateRevision,
    required this.variantId,
    required this.schedule,
    required this.transitionAfter,
  }) {
    if (templateRevision <= 0) {
      throw ArgumentError.value(templateRevision, 'templateRevision');
    }
  }
  final CatalogId id;
  final CatalogId templateId;
  final int templateRevision;
  final CatalogId variantId;
  final FlexibleSchedule schedule;
  final TrainingMaxTransition transitionAfter;
}

final class ProgramPhase {
  ProgramPhase({
    required this.id,
    required this.role,
    required Iterable<ProgramSegment> segments,
  }) : segments = UnmodifiableListView(List.of(segments)) {
    if (this.segments.isEmpty) {
      throw ArgumentError('A phase requires segments.');
    }
  }
  final CatalogId id;
  final ProgramPhaseRole role;
  final List<ProgramSegment> segments;
}

final class FiniteProgramDefinition implements CatalogFiniteProgram {
  FiniteProgramDefinition({
    required this.id,
    required this.revision,
    required this.governance,
    required Iterable<ProgramPhase> phases,
    this.evidence,
  }) : phases = UnmodifiableListView(List.of(phases)) {
    if (revision <= 0 || this.phases.isEmpty) {
      throw ArgumentError('Invalid finite program.');
    }
    if (governance.authority != CatalogAuthority.userCustom &&
        evidence == null) {
      throw ArgumentError(
        'Canonical and compatible programs require evidence.',
      );
    }
    if (this.phases.map((phase) => phase.id).toSet().length !=
        this.phases.length) {
      throw ArgumentError('Duplicate phase ID.');
    }
  }
  @override
  final CatalogId id;
  @override
  final int revision;
  @override
  final CatalogGovernance governance;
  final CatalogEvidence? evidence;
  final List<ProgramPhase> phases;
}

abstract interface class FiniteProgramComposer {
  List<ContractIssue> validate(
    CatalogSnapshot snapshot,
    FiniteProgramDefinition definition,
  );
  FlexibleSchedule compose(
    CatalogSnapshot snapshot,
    FiniteProgramDefinition definition,
  );
}
