enum ImportSeverity { warning, error }

class ImportIssue {
  const ImportIssue({
    required this.path,
    required this.message,
    required this.severity,
  });

  final String path;
  final String message;
  final ImportSeverity severity;
}

class ImportCandidate {
  const ImportCandidate({
    required this.sourceFormat,
    required this.schemaVersion,
    required this.payload,
  });

  final String sourceFormat;
  final int schemaVersion;
  final Map<String, Object?> payload;
}

class ImportInspection {
  const ImportInspection({required this.candidate, required this.issues});

  final ImportCandidate? candidate;
  final List<ImportIssue> issues;

  bool get canImport =>
      candidate != null &&
      issues.every((issue) => issue.severity != ImportSeverity.error);
}

class ImportReport {
  const ImportReport({
    required this.dryRun,
    required this.applied,
    required this.sourceFormat,
    required this.issues,
  });

  final bool dryRun;
  final bool applied;
  final String? sourceFormat;
  final List<ImportIssue> issues;
}
