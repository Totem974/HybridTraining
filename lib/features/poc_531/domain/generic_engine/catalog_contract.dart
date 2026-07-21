import 'dart:collection';

final class CatalogId {
  CatalogId(String value) : value = value.trim() {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(this.value)) {
      throw ArgumentError.value(value, 'value', 'Invalid stable catalog ID.');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) => other is CatalogId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

enum CatalogAuthority { canonical, compatible, userCustom }

enum CatalogReviewStatus { needsReview, confirmed, rejected }

enum CatalogLifecycle {
  draft,
  inReview,
  approved,
  published,
  retired,
  rejected,
}

enum CatalogVisibility { public, internal }

final class EvidenceReference {
  EvidenceReference({
    required this.sourceId,
    required String locator,
    required this.sourceRevision,
  }) : locator = locator.trim() {
    if (this.locator.isEmpty || sourceRevision <= 0) {
      throw ArgumentError('Evidence locator and source revision are required.');
    }
  }

  final CatalogId sourceId;
  final String locator;
  final int sourceRevision;
}

final class CatalogEvidence {
  CatalogEvidence({
    required this.ruleId,
    required Iterable<EvidenceReference> references,
  }) : references = UnmodifiableListView(List.of(references)) {
    if (this.references.isEmpty) {
      throw ArgumentError('Evidence references are required.');
    }
  }

  final CatalogId ruleId;
  final List<EvidenceReference> references;
}

final class CatalogGovernance {
  CatalogGovernance({
    required this.authority,
    required this.review,
    required this.lifecycle,
    required this.visibility,
    required this.executable,
    this.customMetadata,
  }) {
    if (authority == CatalogAuthority.userCustom && customMetadata == null) {
      throw ArgumentError('Custom catalog items require metadata.');
    }
    if (authority != CatalogAuthority.userCustom && customMetadata != null) {
      throw ArgumentError(
        'Custom metadata is only valid for user custom items.',
      );
    }
  }

  final CatalogAuthority authority;
  final CatalogReviewStatus review;
  final CatalogLifecycle lifecycle;
  final CatalogVisibility visibility;
  final bool executable;
  final CustomCatalogMetadata? customMetadata;

  bool get isExecutable =>
      review == CatalogReviewStatus.confirmed &&
      lifecycle == CatalogLifecycle.published &&
      executable;
  bool get isPublic => isExecutable && visibility == CatalogVisibility.public;

  void requireExecutable() {
    if (!isExecutable) {
      throw StateError('Catalog item is not executable.');
    }
  }
}

final class CustomCatalogMetadata {
  CustomCatalogMetadata({
    required this.ownerId,
    required this.derivedFrom,
    required String diff,
  }) : diff = diff.trim() {
    if (this.diff.isEmpty) {
      throw ArgumentError('Custom diff is required.');
    }
  }
  final CatalogId ownerId;
  final CatalogId derivedFrom;
  final String diff;
}

enum MovementKind {
  barbell,
  dumbbell,
  machine,
  bodyweight,
  conditioning,
  other,
}

enum BodyRegion { upper, lower, fullBody, conditioning }

enum LoadKind {
  none,
  externalWeight,
  machineSetting,
  equipmentSetting,
  bodyweight,
  assistedBodyweight,
  addedBodyweightLoad,
  percentTrainingMax,
  percentOneRepMax,
}

final class MovementDefinition {
  MovementDefinition({
    required this.id,
    required this.governance,
    required this.kind,
    required this.bodyRegion,
    required Set<CatalogId> capabilities,
    this.evidence,
  }) : capabilities = UnmodifiableSetView(Set.of(capabilities)) {
    if (governance.authority != CatalogAuthority.userCustom &&
        evidence == null) {
      throw ArgumentError(
        'Canonical and compatible movements require evidence.',
      );
    }
  }

  final CatalogId id;
  final CatalogGovernance governance;
  final MovementKind kind;
  final BodyRegion bodyRegion;
  final Set<CatalogId> capabilities;
  final CatalogEvidence? evidence;
}

final class CatalogSnapshot {
  CatalogSnapshot({
    required this.id,
    required this.revision,
    required String contentHash,
    required this.canonicalizationVersion,
    required Iterable<MovementDefinition> movements,
    required Iterable<TemplateGraph> templates,
    required Iterable<CatalogModule> modules,
    required Iterable<CatalogFiniteProgram> finitePrograms,
  }) : contentHash = contentHash.trim(),
       movements = UnmodifiableListView(List.of(movements)),
       templates = UnmodifiableListView(List.of(templates)),
       modules = UnmodifiableListView(List.of(modules)),
       finitePrograms = UnmodifiableListView(List.of(finitePrograms)) {
    if (revision <= 0) {
      throw ArgumentError.value(revision, 'revision');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(this.contentHash)) {
      throw ArgumentError.value(
        contentHash,
        'contentHash',
        'Must be a lowercase SHA-256 hexadecimal digest.',
      );
    }
    if (canonicalizationVersion <= 0) {
      throw ArgumentError.value(
        canonicalizationVersion,
        'canonicalizationVersion',
        'Must be positive.',
      );
    }
    _requireUnique(this.movements.map((item) => item.id), 'movement');
    _requireUniqueKeys(
      this.templates.map((item) => '${item.id}:${item.revision}'),
      'template revision',
    );
    _requireUniqueKeys(
      this.modules.map((item) => '${item.id}:${item.revision}'),
      'module revision',
    );
    _requireUniqueKeys(
      this.finitePrograms.map((item) => '${item.id}:${item.revision}'),
      'finite program revision',
    );
  }

  final CatalogId id;
  final int revision;
  final String contentHash;
  final int canonicalizationVersion;
  final List<MovementDefinition> movements;
  final List<TemplateGraph> templates;
  final List<CatalogModule> modules;
  final List<CatalogFiniteProgram> finitePrograms;

  MovementDefinition requireMovement(CatalogId id) => movements.firstWhere(
    (movement) => movement.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Unknown movement.'),
  );

  TemplateGraph requireTemplate(CatalogId id, int revision) =>
      templates.firstWhere(
        (template) => template.id == id && template.revision == revision,
        orElse: () => throw ArgumentError.value(id, 'id', 'Unknown template.'),
      );

  Iterable<TemplateGraph> get executableTemplates =>
      templates.where((template) => template.governance.isExecutable);

  Iterable<TemplateGraph> get publicTemplates =>
      templates.where((template) => template.governance.isPublic);
}

abstract interface class CatalogSnapshotPort {
  Future<CatalogSnapshot> load(CatalogId snapshotId, {int? revision});
}

void _requireUnique(Iterable<CatalogId> ids, String label) {
  final values = ids.toList(growable: false);
  if (values.toSet().length != values.length) {
    throw ArgumentError('Duplicate $label ID.');
  }
}

// Avoid a circular public API while keeping snapshot DTOs in one contract.
abstract interface class TemplateGraph {
  CatalogId get id;
  int get revision;
  CatalogGovernance get governance;
}

void _requireUniqueKeys(Iterable<String> keys, String label) {
  final values = keys.toList(growable: false);
  if (values.toSet().length != values.length) {
    throw ArgumentError('Duplicate $label.');
  }
}

abstract interface class CatalogModule {
  CatalogId get id;
  int get revision;
  CatalogGovernance get governance;
  CatalogEvidence? get evidence;
}

abstract interface class CatalogFiniteProgram {
  CatalogId get id;
  int get revision;
  CatalogGovernance get governance;
}
