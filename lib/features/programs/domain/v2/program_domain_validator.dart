import 'program_domain.dart';

enum ProgramDomainIssueCode {
  duplicateId,
  missingReference,
  blueprintWithoutVersion,
  missingRequiredPolicy,
  invalidTransition,
  emptySequence,
  seventhWeekWithoutPurpose,
  unverifiedAvailableRule,
  incompatibleFrequency,
  missingGenerator,
  unorderedCycle,
}

class ProgramDomainIssue {
  const ProgramDomainIssue(this.code, this.message);
  final ProgramDomainIssueCode code;
  final String message;
}

class ProgramDomainValidation {
  const ProgramDomainValidation(this.issues);
  final List<ProgramDomainIssue> issues;
  bool get isValid => issues.isEmpty;
}

class ProgramDomainValidator {
  const ProgramDomainValidator();
  ProgramDomainValidation validate(ComposableProgramDomain domain) {
    final issues = <ProgramDomainIssue>[];
    _duplicates(domain.concepts.map((e) => e.id.value), 'concept', issues);
    _duplicates(domain.revisions.map((e) => e.id.value), 'revision', issues);
    _duplicates(domain.blueprints.map((e) => e.id.value), 'blueprint', issues);
    final concepts = domain.concepts.map((e) => e.id).toSet();
    final revisions = domain.revisions.map((e) => e.id).toSet();
    for (final revision in domain.revisions) {
      if (!concepts.contains(revision.conceptId)) {
        _add(
          issues,
          ProgramDomainIssueCode.missingReference,
          'Missing concept ${revision.conceptId}.',
        );
      }
      if (revision.supersedes != null &&
          !revisions.contains(revision.supersedes)) {
        _add(
          issues,
          ProgramDomainIssueCode.missingReference,
          'Missing superseded revision ${revision.supersedes}.',
        );
      }
    }
    for (final blueprint in domain.blueprints) {
      if (!blueprint.version.isSpecified) {
        _add(
          issues,
          ProgramDomainIssueCode.blueprintWithoutVersion,
          '${blueprint.id} has no version.',
        );
      }
      for (final id in blueprint.revisionIds) {
        if (!revisions.contains(id)) {
          _add(
            issues,
            ProgramDomainIssueCode.missingReference,
            '${blueprint.id} references missing revision $id.',
          );
        }
      }
      if (blueprint.trainingMaxPolicy == null ||
          blueprint.mainWorkPolicy == null ||
          blueprint.schedulePolicy == null) {
        _add(
          issues,
          ProgramDomainIssueCode.missingRequiredPolicy,
          '${blueprint.id} lacks a required policy.',
        );
      }
      final schedule = blueprint.schedulePolicy;
      if (schedule != null &&
          (!schedule.supportedFrequencies.contains(
                schedule.recommendedFrequency,
              ) ||
              !blueprint.compatibility.supportedFrequencies.containsAll(
                schedule.supportedFrequencies,
              ))) {
        _add(
          issues,
          ProgramDomainIssueCode.incompatibleFrequency,
          '${blueprint.id} has incompatible frequencies.',
        );
      }
      if (!blueprint.capabilities.containsAll(
        blueprint.compatibility.requiredCapabilities,
      )) {
        _add(
          issues,
          ProgramDomainIssueCode.incompatibleFrequency,
          '${blueprint.id} lacks a required capability.',
        );
      }
      if (blueprint.blockSequence.blocks.isEmpty) {
        _add(
          issues,
          ProgramDomainIssueCode.emptySequence,
          '${blueprint.id} has no block.',
        );
      }
      final templates = {
        for (final block in blueprint.blockTemplates) block.id: block,
      };
      for (final entry in blueprint.blockSequence.blocks) {
        final template = templates[entry.templateId];
        if (template == null) {
          _add(
            issues,
            ProgramDomainIssueCode.missingReference,
            '${blueprint.id} references missing block ${entry.templateId}.',
          );
        }
        if (template?.role == BlockRole.seventhWeek &&
            template?.seventhWeekPurpose == null) {
          _add(
            issues,
            ProgramDomainIssueCode.seventhWeekWithoutPurpose,
            '${template!.id} has no purpose.',
          );
        }
      }
      final ordered = [...blueprint.blockSequence.blocks]
        ..sort((a, b) => a.order.compareTo(b.order));
      if (ordered.map((e) => e.order).toSet().length != ordered.length ||
          ordered.asMap().entries.any((e) => e.value.order != e.key)) {
        _add(
          issues,
          ProgramDomainIssueCode.unorderedCycle,
          '${blueprint.id} cannot be ordered.',
        );
      }
      if (blueprint.transitionPolicy == null && ordered.length > 1) {
        _add(
          issues,
          ProgramDomainIssueCode.invalidTransition,
          '${blueprint.id} has no transition policy.',
        );
      }
      for (var index = 1; index < ordered.length; index++) {
        final from = templates[ordered[index - 1].templateId];
        final to = templates[ordered[index].templateId];
        if (from != null &&
            to != null &&
            !(blueprint.transitionPolicy?.allowedTransitions.contains(
                  BlockTransition(from.role, to.role),
                ) ??
                false)) {
          _add(
            issues,
            ProgramDomainIssueCode.invalidTransition,
            '${from.role} cannot transition to ${to.role}.',
          );
        }
      }
      final policies = <VersionedPolicy?>[
        blueprint.trainingMaxPolicy,
        blueprint.mainWorkPolicy,
        blueprint.supplementalPolicy,
        blueprint.assistancePolicy,
        blueprint.conditioningPolicy,
        blueprint.athleticWorkPolicy,
        blueprint.schedulePolicy,
        blueprint.transitionPolicy,
      ];
      if (blueprint.implementationStatus == ImplementationStatus.available &&
          (domain.revisions
                  .where((e) => blueprint.revisionIds.contains(e.id))
                  .any((e) => e.ruleStatus != RuleStatus.verified) ||
              policies.whereType<VersionedPolicy>().any(
                (e) => e.ruleStatus != RuleStatus.verified,
              ))) {
        _add(
          issues,
          ProgramDomainIssueCode.unverifiedAvailableRule,
          '${blueprint.id} contains an unverified rule.',
        );
      }
      if (blueprint.implementationStatus == ImplementationStatus.available &&
          (blueprint.generatorId == null || blueprint.generatorId!.isEmpty)) {
        _add(
          issues,
          ProgramDomainIssueCode.missingGenerator,
          '${blueprint.id} has no generator.',
        );
      }
    }
    return ProgramDomainValidation(List.unmodifiable(issues));
  }

  static void _duplicates(
    Iterable<String> ids,
    String kind,
    List<ProgramDomainIssue> issues,
  ) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        _add(
          issues,
          ProgramDomainIssueCode.duplicateId,
          'Duplicate $kind id $id.',
        );
      }
    }
  }

  static void _add(
    List<ProgramDomainIssue> issues,
    ProgramDomainIssueCode code,
    String message,
  ) => issues.add(ProgramDomainIssue(code, message));
}
