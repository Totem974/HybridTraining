class CoreValidationSnapshot {
  const CoreValidationSnapshot({
    required this.profileName,
    required this.unit,
    required this.activePlans,
    required this.plannedSessions,
    required this.completedSessions,
    required this.successfulSets,
    required this.failedSets,
    required this.skippedSets,
    required this.actualTonnage,
  });

  const CoreValidationSnapshot.empty()
    : profileName = null,
      unit = null,
      activePlans = 0,
      plannedSessions = 0,
      completedSessions = 0,
      successfulSets = 0,
      failedSets = 0,
      skippedSets = 0,
      actualTonnage = null;

  final String? profileName;
  final String? unit;
  final int activePlans;
  final int plannedSessions;
  final int completedSessions;
  final int successfulSets;
  final int failedSets;
  final int skippedSets;
  final double? actualTonnage;

  bool get hasProfile => profileName != null;
}
