import 'package:sqflite/sqflite.dart';

import '../../../core/database/catalog/catalog_publication_service.dart';
import '../domain/generic_engine/catalog_contract.dart';
import '../domain/generic_engine/template_graph.dart';

abstract interface class CatalogSnapshotCodec {
  List<ParameterDefinition> decodeParameterSchema(String source);

  ModuleDefinition decodeModuleDefinition(
    String source, {
    required CatalogId id,
    required int revision,
    required CatalogGovernance governance,
    CatalogEvidence? evidence,
  });

  ModuleBinding decodeModuleBindingConfiguration(
    String source, {
    required CatalogId id,
    required CatalogId moduleId,
    required int moduleRevision,
  });
}

final class CatalogSnapshotLoadException implements Exception {
  const CatalogSnapshotLoadException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'CatalogSnapshotLoadException($code)';
}

/// Read-only, fail-closed adapter from a published catalog.db to the pure Dart
/// cycle V5 contract.
final class SqliteCatalogSnapshotRepository implements CatalogSnapshotPort {
  const SqliteCatalogSnapshotRepository({
    required this.database,
    required this.codec,
    this.publicationService = const CatalogPublicationService(),
  });

  static const supportedCanonicalizationVersion = 1;

  final DatabaseExecutor database;
  final CatalogSnapshotCodec codec;
  final CatalogPublicationService publicationService;

  @override
  Future<CatalogSnapshot> load(CatalogId snapshotId, {int? revision}) async {
    if (revision != null && revision <= 0) {
      throw CatalogSnapshotLoadException('version.invalid_revision', revision);
    }
    try {
      final version = await _loadTrustedVersion(snapshotId, revision);
      final versionId = _string(version, 'id');
      await _rejectUnsupportedTopLevelDefinitions(versionId);

      final movements = await _loadMovements(versionId);
      final templatesAndModules = await _loadTemplates(versionId);
      return CatalogSnapshot(
        id: CatalogId(versionId),
        revision: _integer(version, 'ordinal'),
        contentHash: _string(version, 'content_hash'),
        canonicalizationVersion: _integer(version, 'canonicalization_version'),
        movements: movements,
        templates: templatesAndModules.templates,
        modules: templatesAndModules.modules,
        finitePrograms: const [],
      );
    } on CatalogSnapshotLoadException {
      rethrow;
    } on Object catch (error) {
      throw CatalogSnapshotLoadException('catalog.not_decodable', error);
    }
  }

  Future<Map<String, Object?>> _loadTrustedVersion(
    CatalogId snapshotId,
    int? revision,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT v.*, p.validated_content_hash, p.evidence_valid,
                p.licences_valid, p.dependencies_valid, p.children_valid,
                p.blockers_clear, p.signature_valid
         FROM catalog_versions v
         JOIN catalog_publication_validations p ON p.catalog_version_id=v.id
         WHERE v.id=?${revision == null ? '' : ' AND v.ordinal=?'}''',
      [snapshotId.value, ?revision],
    );
    if (rows.length != 1) {
      throw const CatalogSnapshotLoadException('version.not_found');
    }
    final version = rows.single;
    if (version['status'] != 'published' || version['published_at'] == null) {
      throw const CatalogSnapshotLoadException('version.not_published');
    }
    if (_integer(version, 'canonicalization_version') !=
        supportedCanonicalizationVersion) {
      throw const CatalogSnapshotLoadException(
        'version.canonicalization_unsupported',
      );
    }
    final contentHash = _string(version, 'content_hash');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
      throw const CatalogSnapshotLoadException('version.hash_invalid');
    }
    if (version['validated_content_hash'] != contentHash ||
        const [
          'evidence_valid',
          'licences_valid',
          'dependencies_valid',
          'children_valid',
          'blockers_clear',
        ].any((field) => version[field] != 1)) {
      throw const CatalogSnapshotLoadException('version.receipt_invalid');
    }
    final trustChannel = version['trust_channel'];
    if (!const {
      'localReview',
      'bundled',
      'signedRemote',
    }.contains(trustChannel)) {
      throw const CatalogSnapshotLoadException('version.trust_unsupported');
    }
    if (trustChannel == 'signedRemote' &&
        (version['signature_verified'] != 1 ||
            version['signature_valid'] != 1 ||
            version['signature'] == null ||
            version['signature_key_id'] == null ||
            version['signature_algorithm'] == null)) {
      throw const CatalogSnapshotLoadException('version.signature_untrusted');
    }
    final computedHash = await publicationService.computeContentHash(
      database,
      catalogVersionId: snapshotId.value,
    );
    if (computedHash != contentHash) {
      throw const CatalogSnapshotLoadException('version.hash_mismatch');
    }
    return version;
  }

  Future<void> _rejectUnsupportedTopLevelDefinitions(String versionId) async {
    if ((await database.query(
      'declarative_rules',
      columns: const ['id'],
      where: 'catalog_version_id=?',
      whereArgs: [versionId],
      limit: 1,
    )).isNotEmpty) {
      throw const CatalogSnapshotLoadException('declarative_rule.unsupported');
    }
    if ((await database.query(
      'finite_programs',
      columns: const ['id'],
      where: 'catalog_version_id=?',
      whereArgs: [versionId],
      limit: 1,
    )).isNotEmpty) {
      throw const CatalogSnapshotLoadException('finite_program.unsupported');
    }
    if ((await database.rawQuery(
      "SELECT 1 FROM templates WHERE catalog_version_id=? AND kind!='cycle' LIMIT 1",
      [versionId],
    )).isNotEmpty) {
      throw const CatalogSnapshotLoadException('template.kind_unsupported');
    }
    if ((await database.rawQuery(
      '''SELECT 1 FROM variants v
         JOIN templates t ON t.id=v.template_id
         WHERE v.catalog_version_id=? AND v.status='executable'
           AND NOT EXISTS (SELECT 1 FROM engine_bindings b
             WHERE b.variant_id=v.id AND b.engine_kind='cycleV5'
               AND b.status='executable')
         LIMIT 1''',
      [versionId],
    )).isNotEmpty) {
      throw const CatalogSnapshotLoadException(
        'engine_binding.cycle_v5_missing',
      );
    }
  }

  Future<List<MovementDefinition>> _loadMovements(String versionId) async {
    final rows = await database.rawQuery(
      '''SELECT m.*, e.authority, e.review_status AS entry_review_status,
                e.implementation_status, e.execution_status, e.visibility,
                e.license_status
         FROM movements m
         JOIN catalog_entries e ON e.id=m.catalog_entry_id
         WHERE m.catalog_version_id=? ORDER BY m.stable_key''',
      [versionId],
    );
    final result = <MovementDefinition>[];
    for (final row in rows) {
      final evidence = await _loadEvidence(
        versionId,
        subjectType: 'movement',
        subjectId: _string(row, 'id'),
      );
      final capabilities = await database.query(
        'movement_capabilities',
        columns: const ['capability_id'],
        where: 'catalog_version_id=? AND movement_id=?',
        whereArgs: [versionId, row['id']],
        orderBy: 'capability_id',
      );
      result.add(
        MovementDefinition(
          id: CatalogId(_string(row, 'stable_key')),
          governance: _governance(row),
          kind: _movementKind(_string(row, 'kind')),
          bodyRegion: _bodyRegion(_string(row, 'body_region')),
          capabilities: {
            for (final capability in capabilities)
              CatalogId(_string(capability, 'capability_id')),
          },
          evidence: evidence,
        ),
      );
    }
    return result;
  }

  Future<
    ({List<TrainingTemplateGraph> templates, List<ModuleDefinition> modules})
  >
  _loadTemplates(String versionId) async {
    final templateRows = await database.rawQuery(
      '''SELECT DISTINCT t.*, e.authority,
                e.review_status AS entry_review_status,
                e.implementation_status, e.execution_status, e.visibility,
                e.license_status
         FROM templates t
         JOIN catalog_entries e ON e.id=t.catalog_entry_id
         JOIN variants v ON v.template_id=t.id AND v.status='executable'
         JOIN engine_bindings b ON b.variant_id=v.id
           AND b.engine_kind='cycleV5' AND b.status='executable'
         WHERE t.catalog_version_id=? AND t.kind='cycle'
         ORDER BY t.stable_key''',
      [versionId],
    );
    final definitions = <String, ModuleDefinition>{};
    final templates = <TrainingTemplateGraph>[];
    for (final templateRow in templateRows) {
      final templateId = _string(templateRow, 'id');
      final stableTemplateId = CatalogId(_string(templateRow, 'stable_key'));
      final templateRevision = _integer(templateRow, 'revision');
      final templateEvidence = await _loadEvidence(
        versionId,
        subjectType: 'template',
        subjectId: templateId,
      );
      final variantRows = await database.rawQuery(
        '''SELECT v.* FROM variants v
           WHERE v.catalog_version_id=? AND v.template_id=?
             AND v.status='executable'
             AND EXISTS (SELECT 1 FROM engine_bindings b
               WHERE b.variant_id=v.id AND b.engine_kind='cycleV5'
                 AND b.status='executable')
           ORDER BY v.stable_key''',
        [versionId, templateId],
      );
      if (variantRows.isEmpty) {
        throw const CatalogSnapshotLoadException('template.variant_missing');
      }
      if (variantRows.length != 1) {
        throw const CatalogSnapshotLoadException(
          'template.variant_parameter_schema_unsupported',
        );
      }
      final parameters = <ParameterDefinition>[];
      final bindings = <ModuleBinding>[];
      final variants = <TemplateVariant>[];
      for (final variantRow in variantRows) {
        final variantId = _string(variantRow, 'id');
        await _loadEvidence(
          versionId,
          subjectType: 'variant',
          subjectId: variantId,
        );
        await _validateCycleBinding(
          versionId,
          variantId,
          stableTemplateId,
          templateRevision,
        );
        final schemas = await database.query(
          'parameter_schemas',
          where: 'catalog_version_id=? AND variant_id=?',
          whereArgs: [versionId, variantId],
          orderBy: 'schema_version',
        );
        if (schemas.length != 1) {
          throw const CatalogSnapshotLoadException(
            'parameter_schema.unsupported_count',
          );
        }
        if (schemas.single['schema_version'] != 1) {
          throw const CatalogSnapshotLoadException(
            'parameter_schema.version_unsupported',
          );
        }
        parameters.addAll(
          codec.decodeParameterSchema(_string(schemas.single, 'schema_json')),
        );
        final bindingRows = await database.rawQuery(
          '''SELECT mb.*, mv.revision AS module_revision,
                    mv.definition_json, mv.review_status AS module_review_status,
                    m.stable_key AS module_stable_key,
                    e.authority, e.review_status AS entry_review_status,
                    e.implementation_status, e.execution_status, e.visibility,
                    e.license_status
             FROM variant_module_bindings mb
             JOIN module_versions mv ON mv.id=mb.module_version_id
             JOIN modules m ON m.id=mv.module_id
             JOIN catalog_entries e ON e.id=mv.catalog_entry_id
             WHERE mb.catalog_version_id=? AND mb.variant_id=?
             ORDER BY mb.sequence, mb.role, mb.id''',
          [versionId, variantId],
        );
        final variantBindingIds = <CatalogId>{};
        for (final row in bindingRows) {
          if (row['module_review_status'] != 'confirmed') {
            throw const CatalogSnapshotLoadException(
              'module.review_unconfirmed',
            );
          }
          final moduleVersionId = _string(row, 'module_version_id');
          final moduleEvidence = await _loadEvidence(
            versionId,
            subjectType: 'moduleVersion',
            subjectId: moduleVersionId,
          );
          final moduleId = CatalogId(_string(row, 'module_stable_key'));
          final moduleRevision = _integer(row, 'module_revision');
          final definitionKey = '$moduleId:$moduleRevision';
          if (!definitions.containsKey(definitionKey)) {
            final definition = codec.decodeModuleDefinition(
              _string(row, 'definition_json'),
              id: moduleId,
              revision: moduleRevision,
              governance: _governance(row),
              evidence: moduleEvidence,
            );
            _requireSupportedPorts([
              ...definition.inputPorts,
              ...definition.outputPorts,
            ]);
            definitions[definitionKey] = definition;
          }
          final binding = codec.decodeModuleBindingConfiguration(
            _string(row, 'configuration_json'),
            id: CatalogId(_string(row, 'id')),
            moduleId: moduleId,
            moduleRevision: moduleRevision,
          );
          if (binding.moduleId != moduleId ||
              binding.moduleRevision != moduleRevision) {
            throw const CatalogSnapshotLoadException(
              'module_binding.context_mismatch',
            );
          }
          _requireSupportedPorts(binding.inputs);
          bindings.add(binding);
          variantBindingIds.add(binding.id);
        }
        variants.add(
          TemplateVariant(
            id: CatalogId(_string(variantRow, 'stable_key')),
            moduleIds: variantBindingIds,
          ),
        );
      }
      templates.add(
        TrainingTemplateGraph(
          id: stableTemplateId,
          revision: templateRevision,
          governance: _governance(templateRow),
          variants: variants,
          parameters: parameters,
          modules: bindings,
          evidence: templateEvidence,
        ),
      );
    }
    return (templates: templates, modules: definitions.values.toList());
  }

  Future<void> _validateCycleBinding(
    String versionId,
    String variantId,
    CatalogId templateId,
    int templateRevision,
  ) async {
    final rows = await database.query(
      'engine_bindings',
      where:
          "catalog_version_id=? AND variant_id=? AND engine_kind='cycleV5' AND status='executable'",
      whereArgs: [versionId, variantId],
    );
    if (rows.length != 1) {
      throw const CatalogSnapshotLoadException(
        'engine_binding.unsupported_count',
      );
    }
    final row = rows.single;
    if (_string(row, 'definition_id') != templateId.value ||
        _integer(row, 'definition_revision') != templateRevision) {
      throw const CatalogSnapshotLoadException(
        'engine_binding.definition_mismatch',
      );
    }
  }

  Future<CatalogEvidence> _loadEvidence(
    String versionId, {
    required String subjectType,
    required String subjectId,
  }) async {
    final rows = await database.rawQuery(
      '''SELECT e.rule_id, s.id AS source_id, s.locator, s.revision
         FROM evidence e JOIN sources s ON s.id=e.source_id
         WHERE e.catalog_version_id=? AND e.subject_type=? AND e.subject_id=?
           AND e.review_status='confirmed'
         ORDER BY e.rule_id, s.id, s.revision, s.locator''',
      [versionId, subjectType, subjectId],
    );
    if (rows.isEmpty) {
      throw CatalogSnapshotLoadException(
        'evidence.missing',
        '$subjectType:$subjectId',
      );
    }
    final ruleIds = rows.map((row) => _string(row, 'rule_id')).toSet();
    if (ruleIds.length != 1) {
      throw CatalogSnapshotLoadException(
        'evidence.multiple_rules_unsupported',
        '$subjectType:$subjectId',
      );
    }
    return CatalogEvidence(
      ruleId: CatalogId(ruleIds.single),
      references: [
        for (final row in rows)
          EvidenceReference(
            sourceId: CatalogId(_string(row, 'source_id')),
            locator: _string(row, 'locator'),
            sourceRevision: _integer(row, 'revision'),
          ),
      ],
    );
  }
}

void _requireSupportedPorts(Iterable<Object> ports) {
  const supported = {
    ModulePortKind.movement,
    ModulePortKind.parameter,
    ModulePortKind.module,
  };
  for (final port in ports) {
    final kind = switch (port) {
      ModulePort(:final kind) => kind,
      PortBinding(:final kind) => kind,
      _ => throw const CatalogSnapshotLoadException(
        'module.port_not_decodable',
      ),
    };
    if (!supported.contains(kind)) {
      throw CatalogSnapshotLoadException('module.port_unsupported', kind.name);
    }
  }
}

CatalogGovernance _governance(Map<String, Object?> row) {
  final authority = switch (_string(row, 'authority')) {
    'canonical' => CatalogAuthority.canonical,
    'compatible' => CatalogAuthority.compatible,
    'userCustom' => throw const CatalogSnapshotLoadException(
      'governance.user_custom_unsupported',
    ),
    _ => throw const CatalogSnapshotLoadException(
      'governance.authority_unsupported',
    ),
  };
  final review = switch (_string(row, 'entry_review_status')) {
    'needsReview' => CatalogReviewStatus.needsReview,
    'confirmed' => CatalogReviewStatus.confirmed,
    'rejected' => CatalogReviewStatus.rejected,
    _ => throw const CatalogSnapshotLoadException(
      'governance.review_unsupported',
    ),
  };
  final visibility = switch (_string(row, 'visibility')) {
    'visible' => CatalogVisibility.public,
    'internal' || 'hidden' => CatalogVisibility.internal,
    _ => throw const CatalogSnapshotLoadException(
      'governance.visibility_unsupported',
    ),
  };
  return CatalogGovernance(
    authority: authority,
    review: review,
    lifecycle: CatalogLifecycle.published,
    visibility: visibility,
    executable:
        row['implementation_status'] == 'implemented' &&
        row['execution_status'] == 'executable' &&
        const {'ownedReference', 'compatible'}.contains(row['license_status']),
  );
}

MovementKind _movementKind(String value) => switch (value) {
  'conditioning' => MovementKind.conditioning,
  'mainLift' || 'exercise' || 'activity' => MovementKind.other,
  _ => throw CatalogSnapshotLoadException('movement.kind_unsupported', value),
};

BodyRegion _bodyRegion(String value) => switch (value) {
  'upper' => BodyRegion.upper,
  'lower' => BodyRegion.lower,
  'fullBody' => BodyRegion.fullBody,
  'conditioning' => BodyRegion.conditioning,
  _ => throw CatalogSnapshotLoadException(
    'movement.body_region_unsupported',
    value,
  ),
};

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty) {
    throw CatalogSnapshotLoadException('row.invalid_$key', value ?? 'null');
  }
  return value;
}

int _integer(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! int) {
    throw CatalogSnapshotLoadException('row.invalid_$key', value ?? 'null');
  }
  return value;
}
