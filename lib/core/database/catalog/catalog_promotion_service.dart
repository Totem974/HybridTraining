import 'dart:collection';
import 'dart:convert';

import 'catalog_administration_database.dart';

enum CatalogPromotionMode { simulate, apply }

enum PromotionDisposition { promoted, rejected, notAllowlisted }

typedef PromotionHasher = String Function(String canonicalJson);

final class ReviewedPromotionManifest {
  ReviewedPromotionManifest({
    required this.sourceVersionId,
    required this.targetVersionId,
    required this.batchId,
    required this.createdAt,
    required this.completedAt,
    required this.expectedPlanHash,
    required Set<String> allowedSourceKeys,
    required Iterable<ReviewedPromotionItem> items,
  }) : allowedSourceKeys = UnmodifiableSetView(Set.of(allowedSourceKeys)),
       items = UnmodifiableListView(List.of(items));

  final String sourceVersionId;
  final String targetVersionId;
  final String batchId;
  final String createdAt;
  final String completedAt;
  final String expectedPlanHash;
  final Set<String> allowedSourceKeys;
  final List<ReviewedPromotionItem> items;
}

final class ReviewedPromotionItem {
  const ReviewedPromotionItem.promote({
    required this.sourceCatalogEntryKey,
    required this.expectedSourceRecordHash,
    required ReviewedNormalizedEntry this.normalized,
  }) : disposition = PromotionDisposition.promoted,
       rejectionCode = null;

  const ReviewedPromotionItem.reject({
    required this.sourceCatalogEntryKey,
    required this.expectedSourceRecordHash,
    required String this.rejectionCode,
  }) : disposition = PromotionDisposition.rejected,
       normalized = null;

  final String sourceCatalogEntryKey;
  final String expectedSourceRecordHash;
  final PromotionDisposition disposition;
  final ReviewedNormalizedEntry? normalized;
  final String? rejectionCode;
}

final class ReviewedNormalizedEntry {
  ReviewedNormalizedEntry({
    required this.id,
    required this.catalogEntryKey,
    required this.stableDomainId,
    required this.nature,
    required this.authority,
    required this.reviewStatus,
    required this.implementationStatus,
    required this.executionStatus,
    required this.productSurface,
    required this.visibility,
    required this.licenseStatus,
    required Iterable<ReviewedEvidence> evidence,
    Iterable<ReviewedRule> rules = const [],
    Iterable<ReviewedAlias> aliases = const [],
  }) : evidence = UnmodifiableListView(List.of(evidence)),
       rules = UnmodifiableListView(List.of(rules)),
       aliases = UnmodifiableListView(List.of(aliases));

  final String id;
  final String catalogEntryKey;
  final String stableDomainId;
  final String nature;
  final String authority;
  final String reviewStatus;
  final String implementationStatus;
  final String executionStatus;
  final String productSurface;
  final String visibility;
  final String licenseStatus;
  final List<ReviewedEvidence> evidence;
  final List<ReviewedRule> rules;
  final List<ReviewedAlias> aliases;
}

final class ReviewedEvidence {
  const ReviewedEvidence({
    required this.id,
    required this.sourceId,
    required this.editionId,
    required this.sourceLocator,
    required this.pages,
    required this.contentReuse,
    required this.ruleId,
    required this.subjectType,
    required this.subjectId,
    required this.reviewStatus,
    required this.excerptDigest,
    required this.note,
  });
  final String id;
  final String sourceId;
  final String editionId;
  final String sourceLocator;
  final String pages;

  /// `none` means only an original structured representation of facts.
  final String contentReuse;
  final String ruleId;
  final String subjectType;
  final String subjectId;
  final String reviewStatus;
  final String? excerptDigest;
  final String note;
}

final class ReviewedRule {
  const ReviewedRule({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.kind,
    required this.schemaVersion,
    required this.expressionJson,
    required this.blockerCode,
    required this.reviewStatus,
  });
  final String id;
  final String ownerType;
  final String ownerId;
  final String kind;
  final int schemaVersion;
  final String expressionJson;
  final String? blockerCode;
  final String reviewStatus;
}

final class ReviewedAlias {
  const ReviewedAlias({
    required this.id,
    required this.namespace,
    required this.alias,
    required this.evidenceId,
    required this.reviewStatus,
  });
  final String id;
  final String namespace;
  final String alias;
  final String evidenceId;
  final String reviewStatus;
}

final class PromotionDispositionReport {
  const PromotionDispositionReport({
    required this.sourceCatalogEntryKey,
    required this.disposition,
    required this.sourceRecordHash,
    required this.mappingHash,
    required this.normalizedHash,
    required this.issueCode,
  });
  final String sourceCatalogEntryKey;
  final PromotionDisposition disposition;
  final String sourceRecordHash;
  final String? mappingHash;
  final String? normalizedHash;
  final String? issueCode;
}

final class CatalogPromotionReport {
  CatalogPromotionReport({
    required this.mode,
    required this.applied,
    required this.idempotent,
    required this.planHash,
    required this.sourceManifestHash,
    required this.normalizedContentHash,
    required this.targetVersionId,
    required Iterable<String> issues,
    required Iterable<PromotionDispositionReport> dispositions,
  }) : issues = List.unmodifiable(issues),
       dispositions = List.unmodifiable(dispositions);
  final CatalogPromotionMode mode;
  final bool applied;
  final bool idempotent;
  final String planHash;
  final String? sourceManifestHash;
  final String normalizedContentHash;
  final String? targetVersionId;
  final List<String> issues;
  final List<PromotionDispositionReport> dispositions;
  bool get isValid => issues.isEmpty;
}

final class CatalogPromotionService {
  const CatalogPromotionService(this._database, this._hasher);

  final CatalogAdministrationDatabase _database;
  final PromotionHasher _hasher;

  String computePlanHash(ReviewedPromotionManifest manifest) =>
      _hash(_manifestMap(manifest));

  Future<CatalogPromotionReport> promote({
    required ReviewedPromotionManifest manifest,
    CatalogPromotionMode mode = CatalogPromotionMode.simulate,
  }) => _database.transaction((transaction) async {
    final source = await transaction.findVersionById(manifest.sourceVersionId);
    final staged = await transaction.listStagedEntries(
      manifest.sourceVersionId,
    );
    final blockers = await transaction.listImportBlockers(
      manifest.sourceVersionId,
    );
    final planHash = computePlanHash(manifest);
    final issues = <String>[];
    if (source == null) issues.add('source.not_found');
    if (source != null &&
        source.status != 'draft' &&
        source.status != 'inReview') {
      issues.add('source.not_staged');
    }
    if (planHash != manifest.expectedPlanHash) issues.add('plan.hash_mismatch');
    if (blockers.any((value) => value.severity == 'error')) {
      issues.add('source.validation_error');
    }
    final stagedByKey = {
      for (final value in staged) value.catalogEntryKey: value,
    };
    if (source != null &&
        staged.any((value) => value.manifestHash != source.contentHash)) {
      issues.add('source.manifest_hash_mismatch');
    }
    final itemKeys = manifest.items
        .map((value) => value.sourceCatalogEntryKey)
        .toList();
    if (itemKeys.toSet().length != itemKeys.length) {
      issues.add('plan.duplicate_source_key');
    }
    if (manifest.allowedSourceKeys.length != manifest.items.length ||
        !manifest.allowedSourceKeys.containsAll(itemKeys)) {
      issues.add('plan.allowlist_mismatch');
    }
    final dispositions = <PromotionDispositionReport>[];
    for (final item in manifest.items) {
      final sourceEntry = stagedByKey[item.sourceCatalogEntryKey];
      if (sourceEntry == null) {
        issues.add('source.entry_not_found:${item.sourceCatalogEntryKey}');
        continue;
      }
      if (sourceEntry.recordHash != item.expectedSourceRecordHash) {
        issues.add('source.record_hash_mismatch:${item.sourceCatalogEntryKey}');
      }
      if (item.disposition == PromotionDisposition.rejected) {
        issues.add('plan.rejected:${item.sourceCatalogEntryKey}');
        dispositions.add(
          PromotionDispositionReport(
            sourceCatalogEntryKey: item.sourceCatalogEntryKey,
            disposition: item.disposition,
            sourceRecordHash: sourceEntry.recordHash,
            mappingHash: null,
            normalizedHash: null,
            issueCode: item.rejectionCode,
          ),
        );
        continue;
      }
      final normalized = item.normalized!;
      await _validateNormalized(
        transaction,
        item.sourceCatalogEntryKey,
        normalized,
        issues,
      );
      final normalizedHash = _hash(_normalizedMap(normalized));
      final mappingHash = _hash({
        'sourceKey': item.sourceCatalogEntryKey,
        'sourceRecordHash': item.expectedSourceRecordHash,
        'normalizedHash': normalizedHash,
      });
      dispositions.add(
        PromotionDispositionReport(
          sourceCatalogEntryKey: item.sourceCatalogEntryKey,
          disposition: item.disposition,
          sourceRecordHash: sourceEntry.recordHash,
          mappingHash: mappingHash,
          normalizedHash: normalizedHash,
          issueCode: null,
        ),
      );
    }
    for (final entry in staged.where(
      (value) => !manifest.allowedSourceKeys.contains(value.catalogEntryKey),
    )) {
      dispositions.add(
        PromotionDispositionReport(
          sourceCatalogEntryKey: entry.catalogEntryKey,
          disposition: PromotionDisposition.notAllowlisted,
          sourceRecordHash: entry.recordHash,
          mappingHash: null,
          normalizedHash: null,
          issueCode: 'not_allowlisted',
        ),
      );
    }
    dispositions.sort(
      (a, b) => a.sourceCatalogEntryKey.compareTo(b.sourceCatalogEntryKey),
    );
    final normalizedContentHash = _hash(
      dispositions
          .where((value) => value.normalizedHash != null)
          .map(
            (value) => '${value.sourceCatalogEntryKey}:${value.normalizedHash}',
          )
          .toList(),
    );
    CatalogPromotionReport report({
      bool applied = false,
      bool idempotent = false,
      String? target,
    }) => CatalogPromotionReport(
      mode: mode,
      applied: applied,
      idempotent: idempotent,
      planHash: planHash,
      sourceManifestHash: source?.contentHash,
      normalizedContentHash: normalizedContentHash,
      targetVersionId: target,
      issues: issues,
      dispositions: dispositions,
    );
    if (issues.isNotEmpty || mode == CatalogPromotionMode.simulate) {
      return report();
    }
    final existing = await transaction.findAppliedPromotion(
      sourceManifestHash: source!.contentHash,
      targetContentHash: normalizedContentHash,
    );
    if (existing != null) {
      return report(
        applied: true,
        idempotent: true,
        target: existing.catalogVersionId,
      );
    }

    await transaction.insertDraftVersion(
      CatalogDraftVersion(
        id: manifest.targetVersionId,
        ordinal: await transaction.nextVersionOrdinal(),
        status: 'draft',
        parentVersionId: manifest.sourceVersionId,
        contentHash: normalizedContentHash,
        canonicalizationVersion: source.canonicalizationVersion,
        signatureVerified: false,
        trustChannel: 'localReview',
        createdAt: manifest.createdAt,
      ),
    );
    await transaction.insertPromotionBatch(
      CatalogPromotionBatchWrite(
        id: manifest.batchId,
        catalogVersionId: manifest.targetVersionId,
        sourceManifestHash: source.contentHash,
        status: 'planned',
        createdAt: manifest.createdAt,
        completedAt: null,
      ),
    );
    for (final item in manifest.items) {
      final normalized = item.normalized!;
      await transaction.insertGovernedEntry(
        _entryWrite(manifest.targetVersionId, normalized),
      );
      for (final evidence in normalized.evidence) {
        await transaction.insertEvidence(
          _evidenceWrite(manifest.targetVersionId, evidence),
        );
      }
      for (final rule in normalized.rules) {
        await transaction.insertDeclarativeRule(
          _ruleWrite(manifest.targetVersionId, rule),
        );
      }
      for (final alias in normalized.aliases) {
        await transaction.insertEntryAlias(
          CatalogEntryAliasWrite(
            id: alias.id,
            catalogVersionId: manifest.targetVersionId,
            namespace: alias.namespace,
            alias: alias.alias,
            catalogEntryId: normalized.id,
            evidenceId: alias.evidenceId,
            reviewStatus: alias.reviewStatus,
          ),
        );
      }
      await transaction.insertPromotionItem(
        CatalogPromotionItemWrite(
          id: _hash({
            'batch': manifest.batchId,
            'source': item.sourceCatalogEntryKey,
          }),
          promotionBatchId: manifest.batchId,
          catalogVersionId: manifest.targetVersionId,
          catalogEntryKey: item.sourceCatalogEntryKey,
          sourceRecordHash: item.expectedSourceRecordHash,
          targetCatalogEntryId: normalized.id,
          status: 'promoted',
          issueCode: null,
        ),
      );
    }
    await transaction.updatePromotionBatch(
      CatalogPromotionBatchWrite(
        id: manifest.batchId,
        catalogVersionId: manifest.targetVersionId,
        sourceManifestHash: source.contentHash,
        status: 'applied',
        createdAt: manifest.createdAt,
        completedAt: manifest.completedAt,
      ),
    );
    return report(applied: true, target: manifest.targetVersionId);
  });

  Future<void> _validateNormalized(
    CatalogAdministrationTransaction transaction,
    String key,
    ReviewedNormalizedEntry value,
    List<String> issues,
  ) async {
    const catalogIds = r'^[a-z0-9]+(?:-[a-z0-9]+)*$';
    if (value.catalogEntryKey != key) {
      issues.add('mapping.catalog_entry_key:$key');
    }
    if (!RegExp(catalogIds).hasMatch(value.stableDomainId)) {
      issues.add('mapping.stable_domain_id:$key');
    }
    if (!const {
      'cycleDefinition',
      'schedule',
      'policy',
      'component',
      'assistancePlan',
      'finiteProgram',
      'phase',
      'resource',
      'protocol',
      'transition',
      'outOfScope',
      'other',
    }.contains(value.nature)) {
      issues.add('mapping.nature:$key');
    }
    if (!const {
      'canonical',
      'compatible',
      'userCustom',
    }.contains(value.authority)) {
      issues.add('mapping.authority:$key');
    }
    if (value.reviewStatus != 'confirmed') {
      issues.add('mapping.needs_review:$key');
    }
    if (value.visibility == 'visible' && value.reviewStatus != 'confirmed') {
      issues.add('mapping.visibility:$key');
    }
    if (!const {
      'ownedReference',
      'compatible',
      'unknown',
      'restricted',
    }.contains(value.licenseStatus)) {
      issues.add('mapping.license_status:$key');
    }
    final evidenceIds = value.evidence.map((item) => item.id).toSet();
    if (!value.evidence.any(
          (item) =>
              item.subjectType == 'catalogEntry' &&
              item.subjectId == value.id &&
              item.reviewStatus == 'confirmed',
        ) ||
        value.evidence.any((item) => item.reviewStatus != 'confirmed')) {
      issues.add('mapping.evidence:$key');
    }
    for (final evidence in value.evidence) {
      final source = await transaction.findSourceById(evidence.sourceId);
      if (source == null ||
          source.editionId != evidence.editionId ||
          source.locator != evidence.sourceLocator ||
          evidence.pages.trim().isEmpty ||
          evidence.contentReuse != 'none') {
        issues.add('mapping.source:${evidence.id}');
      }
    }
    for (final rule in value.rules) {
      if (rule.schemaVersion != 1 ||
          rule.reviewStatus != 'confirmed' ||
          !const {
            'catalogEntry',
            'template',
            'variant',
            'moduleVersion',
            'schedule',
            'finiteProgram',
            'movement',
            'assistancePlan',
            'policy',
          }.contains(rule.ownerType) ||
          !const {
            'compatibility',
            'visibility',
            'required',
            'constraint',
          }.contains(rule.kind) ||
          !value.evidence.any(
            (item) =>
                item.ruleId == rule.id && item.reviewStatus == 'confirmed',
          )) {
        issues.add('mapping.rule:${rule.id}');
      }
      try {
        jsonDecode(rule.expressionJson);
      } on FormatException {
        issues.add('mapping.rule_json:${rule.id}');
      }
    }
    for (final alias in value.aliases) {
      if (alias.reviewStatus != 'confirmed' ||
          !RegExp(catalogIds).hasMatch(alias.namespace) ||
          !evidenceIds.contains(alias.evidenceId)) {
        issues.add('mapping.alias:${alias.id}');
      }
    }
  }

  CatalogGovernedEntryWrite _entryWrite(
    String version,
    ReviewedNormalizedEntry v,
  ) => CatalogGovernedEntryWrite(
    id: v.id,
    catalogVersionId: version,
    catalogEntryKey: v.catalogEntryKey,
    stableDomainId: v.stableDomainId,
    nature: v.nature,
    authority: v.authority,
    reviewStatus: v.reviewStatus,
    implementationStatus: v.implementationStatus,
    executionStatus: v.executionStatus,
    productSurface: v.productSurface,
    visibility: v.visibility,
    licenseStatus: v.licenseStatus,
  );
  CatalogEvidenceWrite _evidenceWrite(String version, ReviewedEvidence v) =>
      CatalogEvidenceWrite(
        id: v.id,
        catalogVersionId: version,
        sourceId: v.sourceId,
        ruleId: v.ruleId,
        subjectType: v.subjectType,
        subjectId: v.subjectId,
        reviewStatus: v.reviewStatus,
        contentReuse: v.contentReuse,
        excerptDigest: v.excerptDigest,
        note: v.note,
      );
  CatalogDeclarativeRuleWrite _ruleWrite(String version, ReviewedRule v) =>
      CatalogDeclarativeRuleWrite(
        id: v.id,
        catalogVersionId: version,
        ownerType: v.ownerType,
        ownerId: v.ownerId,
        kind: v.kind,
        schemaVersion: v.schemaVersion,
        expressionJson: v.expressionJson,
        blockerCode: v.blockerCode,
        reviewStatus: v.reviewStatus,
      );

  String _hash(Object? value) => _hasher(_canonicalJson(value));
}

Map<String, Object?> _manifestMap(ReviewedPromotionManifest value) => {
  'sourceVersionId': value.sourceVersionId,
  'targetVersionId': value.targetVersionId,
  'batchId': value.batchId,
  'createdAt': value.createdAt,
  'completedAt': value.completedAt,
  'allowedSourceKeys': value.allowedSourceKeys.toList()..sort(),
  'items':
      value.items
          .map(
            (item) => {
              'sourceKey': item.sourceCatalogEntryKey,
              'sourceRecordHash': item.expectedSourceRecordHash,
              'disposition': item.disposition.name,
              'rejectionCode': item.rejectionCode,
              'normalized': item.normalized == null
                  ? null
                  : _normalizedMap(item.normalized!),
            },
          )
          .toList()
        ..sort(
          (a, b) =>
              (a['sourceKey']! as String).compareTo(b['sourceKey']! as String),
        ),
};

Map<String, Object?> _normalizedMap(ReviewedNormalizedEntry v) => {
  'id': v.id,
  'catalogEntryKey': v.catalogEntryKey,
  'stableDomainId': v.stableDomainId,
  'nature': v.nature,
  'authority': v.authority,
  'reviewStatus': v.reviewStatus,
  'implementationStatus': v.implementationStatus,
  'executionStatus': v.executionStatus,
  'productSurface': v.productSurface,
  'visibility': v.visibility,
  'licenseStatus': v.licenseStatus,
  'evidence': v.evidence
      .map(
        (e) => {
          'id': e.id,
          'sourceId': e.sourceId,
          'editionId': e.editionId,
          'sourceLocator': e.sourceLocator,
          'pages': e.pages,
          'contentReuse': e.contentReuse,
          'ruleId': e.ruleId,
          'subjectType': e.subjectType,
          'subjectId': e.subjectId,
          'reviewStatus': e.reviewStatus,
          'excerptDigest': e.excerptDigest,
          'note': e.note,
        },
      )
      .toList(),
  'rules': v.rules
      .map(
        (r) => {
          'id': r.id,
          'ownerType': r.ownerType,
          'ownerId': r.ownerId,
          'kind': r.kind,
          'schemaVersion': r.schemaVersion,
          'expressionJson': r.expressionJson,
          'blockerCode': r.blockerCode,
          'reviewStatus': r.reviewStatus,
        },
      )
      .toList(),
  'aliases': v.aliases
      .map(
        (a) => {
          'id': a.id,
          'namespace': a.namespace,
          'alias': a.alias,
          'evidenceId': a.evidenceId,
          'reviewStatus': a.reviewStatus,
        },
      )
      .toList(),
};

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));
Object? _canonicalize(Object? value) => switch (value) {
  Map map => {
    for (final key in map.keys.map((key) => key.toString()).toList()..sort())
      key: _canonicalize(map[key]),
  },
  Iterable iterable => [for (final item in iterable) _canonicalize(item)],
  _ => value,
};
