final class ComponentReference {
  const ComponentReference(this.id, this.revision)
    : assert(id != ''),
      assert(revision > 0);

  final String id;
  final int revision;
}

final class CatalogWeekOrigin {
  const CatalogWeekOrigin({
    required this.phaseId,
    required this.phaseIteration,
    required this.sourceWeekNumber,
    this.trainingMaxProgressionStep = 0,
  }) : assert(phaseId != ''),
       assert(phaseIteration > 0),
       assert(sourceWeekNumber > 0),
       assert(trainingMaxProgressionStep >= 0);

  final String phaseId;
  final int phaseIteration;
  final int sourceWeekNumber;
  final int trainingMaxProgressionStep;
}

final class CatalogWeekPlan {
  const CatalogWeekPlan({required this.weekNumber, required this.components})
    : assert(weekNumber > 0);

  final int weekNumber;
  final List<ComponentReference> components;
}

final class CatalogPhase {
  const CatalogPhase({
    required this.id,
    required this.repeatCount,
    required this.weekPlans,
    this.trainingMaxProgressionStep = 0,
  }) : assert(id != ''),
       assert(repeatCount > 0),
       assert(trainingMaxProgressionStep >= 0);

  final String id;
  final int repeatCount;
  final List<CatalogWeekPlan> weekPlans;
  final int trainingMaxProgressionStep;
}

final class ExpandedWeekPlan {
  const ExpandedWeekPlan({
    required this.number,
    required this.phaseId,
    required this.phaseIteration,
    required this.sourceWeekNumber,
    required this.components,
    this.trainingMaxProgressionStep = 0,
  });

  final int number;
  final String phaseId;
  final int phaseIteration;
  final int sourceWeekNumber;
  final List<ComponentReference> components;
  final int trainingMaxProgressionStep;
}

final class PhaseExpander {
  const PhaseExpander();

  List<ExpandedWeekPlan> expand(List<CatalogPhase> phases) {
    final result = <ExpandedWeekPlan>[];
    for (final phase in phases) {
      for (var iteration = 1; iteration <= phase.repeatCount; iteration++) {
        for (final week in phase.weekPlans) {
          result.add(
            ExpandedWeekPlan(
              number: result.length + 1,
              phaseId: phase.id,
              phaseIteration: iteration,
              sourceWeekNumber: week.weekNumber,
              components: List.unmodifiable(week.components),
              trainingMaxProgressionStep: phase.trainingMaxProgressionStep,
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }
}
