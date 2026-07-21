import 'package:sqflite/sqflite.dart';

import '../domain/generic_engine/generic_engine.dart';
import 'generic_engine_sqlite_codec.dart';

abstract interface class MaxCalculationRulePort {
  Future<MaxCalculationRule> load({
    required CatalogId ruleId,
    required CatalogId catalogVersionId,
  });
}

final class WorkspaceAssistanceSelection {
  const WorkspaceAssistanceSelection({
    required this.id,
    required this.slotId,
    required this.movementId,
    required this.regular,
    required this.deloadMode,
    this.deload,
  });

  final String id;
  final CatalogId slotId;
  final CatalogId movementId;
  final SetPrescription regular;
  final AssistanceDeloadMode deloadMode;
  final SetPrescription? deload;
}

abstract interface class AssistanceConfigurationPort {
  Future<AssistancePlan> resolve({
    required CatalogId planId,
    required List<WorkspaceAssistanceSelection> selections,
    required CatalogSnapshot snapshot,
  });
}

final class WorkspaceConditioningSelection {
  const WorkspaceConditioningSelection({
    required this.sequence,
    required this.definitionId,
    required this.prescription,
  });

  final int sequence;
  final CatalogId definitionId;
  final ConditioningPrescription prescription;
}

abstract interface class ConditioningConfigurationPort {
  Future<List<ConditioningConfiguration>> resolve({
    required List<WorkspaceConditioningSelection> selections,
    required CatalogSnapshot snapshot,
  });
}

final class EngineRequestLoadException implements Exception {
  const EngineRequestLoadException({
    required this.code,
    required this.path,
    required this.message,
    this.cause,
  });

  final String code;
  final String path;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code at $path: $message';
}

/// Builds an executable engine request from workspace schema v2.
///
/// Catalog-backed definitions are intentionally supplied by ports. The
/// catalog adapter implementing those ports is a separate increment; this
/// repository never reaches into catalog.db itself.
final class SqliteEngineRequestRepository {
  const SqliteEngineRequestRepository({
    required this.database,
    required this.snapshotPort,
    required this.codec,
    required this.maxCalculationRulePort,
    required this.assistanceConfigurationPort,
    required this.conditioningConfigurationPort,
  });

  final DatabaseExecutor database;
  final CatalogSnapshotPort snapshotPort;
  final GenericEngineSqliteCodec codec;
  final MaxCalculationRulePort maxCalculationRulePort;
  final AssistanceConfigurationPort assistanceConfigurationPort;
  final ConditioningConfigurationPort conditioningConfigurationPort;

  Future<EngineRequest> load({
    required String draftId,
    required String athleteId,
  }) async {
    if (draftId.trim().isEmpty || athleteId.trim().isEmpty) {
      throw _error(
        'draft.invalid_identity',
        r'$.draft',
        'IDs must be non-empty.',
      );
    }
    try {
      final draftRow = await _one(
        'workspace_drafts',
        await database.query(
          'workspace_drafts',
          where: 'id = ? AND athlete_id = ?',
          whereArgs: [draftId, athleteId],
        ),
        r'$.draft',
      );
      if (_string(draftRow, 'kind', r'$.draft.kind') != 'configuration') {
        throw _error(
          'draft.unsupported_kind',
          r'$.draft.kind',
          'Only configuration drafts can produce an engine request.',
        );
      }
      if (_integer(
            draftRow,
            'payload_schema_version',
            r'$.draft.payloadSchemaVersion',
          ) !=
          GenericEngineSqliteCodec.schemaVersion) {
        throw _error(
          'draft.unsupported_schema_version',
          r'$.draft.payloadSchemaVersion',
          'The workspace draft schema is unsupported.',
        );
      }

      final catalogVersionId = CatalogId(
        _string(draftRow, 'catalog_version_id', r'$.draft.catalogVersionId'),
      );
      final snapshot = await snapshotPort.load(catalogVersionId);
      _verifyCatalogCoordinates(draftRow, snapshot);

      final decoded = codec.decodeWorkspaceDraft(
        _string(draftRow, 'payload_json', r'$.draft.payload'),
      );
      final profile = await _one(
        'athlete_profiles',
        await database.query(
          'athlete_profiles',
          where: 'id = ?',
          whereArgs: [athleteId],
        ),
        r'$.athlete',
      );
      final rule = await maxCalculationRulePort.load(
        ruleId: decoded.trainingMaxes.calculationRuleId,
        catalogVersionId: catalogVersionId,
      );
      if (rule.id != decoded.trainingMaxes.calculationRuleId) {
        throw _error(
          'training_max.rule_mismatch',
          r'$.trainingMaxes.calculationRuleId',
          'The resolved calculation rule has a different stable ID.',
        );
      }
      rule.governance.requireExecutable();
      final trainingMaxes = decoded.trainingMaxes.resolve(rule);
      await _verifyTrainingMaxes(profile, athleteId, trainingMaxes);

      final equipment = await _loadEquipment(
        draftId,
        athleteId,
        trainingMaxes.unit,
      );
      _verifyEquipmentPayload(decoded.equipment, equipment);

      final assistance = await _loadAssistance(draftId, snapshot);
      _verifyAssistancePayload(decoded.assistance, assistance);
      final conditioning = await _loadConditioning(draftId, snapshot);
      _verifyConditioningPayload(decoded.conditioning, conditioning);

      final request = EngineRequest(
        snapshot: snapshot,
        templateId: decoded.templateId,
        templateRevision: decoded.templateRevision,
        variantId: decoded.variantId,
        parameters: decoded.parameters,
        trainingMaxes: trainingMaxes,
        equipment: equipment,
        assistance: assistance,
        conditioning: conditioning,
      );
      final result = const TemplateContractResolver().resolve(request);
      if (result.issues.isNotEmpty) {
        final issue = result.issues.first;
        throw _error('contract.${issue.code}', issue.path, issue.message);
      }
      return request;
    } on EngineRequestLoadException {
      rethrow;
    } on GenericEngineCodecException catch (error) {
      throw _error('payload.${error.code}', error.path, error.message, error);
    } on Object catch (error) {
      throw _error(
        'workspace.not_loadable',
        r'$',
        'The workspace draft could not be converted safely.',
        error,
      );
    }
  }

  void _verifyCatalogCoordinates(
    Map<String, Object?> row,
    CatalogSnapshot snapshot,
  ) {
    if (snapshot.id.value !=
        _string(row, 'catalog_version_id', r'$.draft.catalogVersionId')) {
      throw _error(
        'catalog.version_mismatch',
        r'$.draft.catalogVersionId',
        'The loaded catalog version does not match the draft.',
      );
    }
    if (snapshot.contentHash !=
        _string(row, 'catalog_content_hash', r'$.draft.catalogContentHash')) {
      throw _error(
        'catalog.hash_mismatch',
        r'$.draft.catalogContentHash',
        'The catalog content hash does not match the draft.',
      );
    }
    if (snapshot.canonicalizationVersion !=
        _integer(
          row,
          'catalog_canonicalization_version',
          r'$.draft.catalogCanonicalizationVersion',
        )) {
      throw _error(
        'catalog.canonicalization_mismatch',
        r'$.draft.catalogCanonicalizationVersion',
        'The catalog canonicalization version does not match the draft.',
      );
    }
  }

  Future<void> _verifyTrainingMaxes(
    Map<String, Object?> profile,
    String athleteId,
    TrainingMaxConfiguration configuration,
  ) async {
    final preferredUnit = _weightUnit(
      _string(profile, 'preferred_unit', r'$.athlete.preferredUnit'),
      r'$.athlete.preferredUnit',
    );
    if (preferredUnit != configuration.unit) {
      throw _error(
        'training_max.unit_mismatch',
        r'$.trainingMaxes.unit',
        'Draft and athlete units differ.',
      );
    }
    final rounding = _nullableNumber(
      profile,
      'rounding_increment',
      r'$.athlete.roundingIncrement',
    );
    if (rounding == null) {
      throw _error(
        'training_max.missing_rounding',
        r'$.athlete.roundingIncrement',
        'A positive rounding increment is required.',
      );
    }
    if (!_sameDouble(rounding, configuration.roundingIncrement)) {
      throw _error(
        'training_max.rounding_mismatch',
        r'$.trainingMaxes.roundingIncrement',
        'Draft and athlete rounding increments differ.',
      );
    }

    final rows = await database.query(
      'weight_profiles',
      where: 'athlete_id = ?',
      whereArgs: [athleteId],
      orderBy: 'movement_key ASC, effective_at DESC',
    );
    final latest = <CatalogId, Map<String, Object?>>{};
    for (final row in rows) {
      latest.putIfAbsent(
        CatalogId(
          _string(row, 'movement_key', r'$.weightProfiles.movementKey'),
        ),
        () => row,
      );
    }
    for (final entry in configuration.inputs.entries) {
      final path = r'$.trainingMaxes.' + entry.key.value;
      final row = latest[entry.key];
      if (row == null) {
        throw _error(
          'training_max.missing_profile',
          path,
          'No persisted Training Max exists for this movement.',
        );
      }
      if (_weightUnit(_string(row, 'unit', '$path.unit'), '$path.unit') !=
          configuration.unit) {
        throw _error(
          'training_max.profile_unit_mismatch',
          '$path.unit',
          'The persisted Training Max uses a different unit.',
        );
      }
      final ratio = _number(row, 'training_max_ratio', '$path.ratio');
      if (!_sameDouble(ratio, configuration.ratioFor(entry.key))) {
        throw _error(
          'training_max.ratio_mismatch',
          '$path.ratio',
          'The persisted global/per-movement ratio differs from the draft.',
        );
      }
      final persistedTrainingMax = _number(row, 'training_max', '$path.value');
      final calculatedTrainingMax = configuration.trainingMaxFor(entry.key);
      if (!_sameDouble(persistedTrainingMax, calculatedTrainingMax)) {
        throw _error(
          'training_max.value_mismatch',
          '$path.value',
          'The persisted Training Max differs from the sourced calculation.',
        );
      }
      final persistedOneRepMax = _nullableNumber(
        row,
        'one_rep_max',
        '$path.oneRepMax',
      );
      if (persistedOneRepMax != null &&
          !_sameDouble(persistedOneRepMax, entry.value.estimatedOneRepMax())) {
        throw _error(
          'training_max.one_rep_max_mismatch',
          '$path.oneRepMax',
          'The persisted one-rep max differs from the draft input.',
        );
      }
    }
  }

  Future<EquipmentProfile> _loadEquipment(
    String draftId,
    String athleteId,
    WeightUnit unit,
  ) async {
    final link = await _one(
      'workspace_draft_equipment',
      await database.query(
        'workspace_draft_equipment',
        where: 'draft_id = ? AND athlete_id = ?',
        whereArgs: [draftId, athleteId],
      ),
      r'$.equipment',
    );
    final gymId = _string(link, 'gym_id', r'$.equipment.gymId');
    final barId = _string(link, 'bar_id', r'$.equipment.barId');
    await _one(
      'gyms',
      await database.query(
        'gyms',
        where: 'id = ? AND athlete_id = ?',
        whereArgs: [gymId, athleteId],
      ),
      r'$.equipment.gym',
    );
    final bar = await _one(
      'bars',
      await database.query(
        'bars',
        where: 'id = ? AND gym_id = ?',
        whereArgs: [barId, gymId],
      ),
      r'$.equipment.bar',
    );
    final expectedUnit = _storedUnit(unit);
    if (_string(bar, 'unit', r'$.equipment.bar.unit') != expectedUnit) {
      throw _error(
        'equipment.bar_unit_mismatch',
        r'$.equipment.bar.unit',
        'The selected bar unit differs from the Training Max unit.',
      );
    }

    final plateRows = await database.query(
      'plates',
      where: 'gym_id = ?',
      whereArgs: [gymId],
      orderBy: 'weight DESC, id ASC',
    );
    final plates = <double>[];
    for (final row in plateRows) {
      if (_string(row, 'unit', r'$.equipment.plates.unit') != expectedUnit) {
        throw _error(
          'equipment.plate_unit_mismatch',
          r'$.equipment.plates.unit',
          'Every available plate must use the Training Max unit.',
        );
      }
      final pairCount =
          _integer(row, 'quantity', r'$.equipment.plates.quantity') ~/ 2;
      final weight = _number(row, 'weight', r'$.equipment.plates.weight');
      for (var index = 0; index < pairCount; index++) {
        plates.add(weight);
      }
    }
    final equipmentIds =
        (await database.query(
              'workspace_draft_equipment_ids',
              columns: ['equipment_id'],
              where: 'draft_id = ?',
              whereArgs: [draftId],
              orderBy: 'equipment_id ASC',
            ))
            .map(
              (row) => CatalogId(
                _string(row, 'equipment_id', r'$.equipment.equipmentIds'),
              ),
            )
            .toSet();
    final supportedLoads =
        (await database.query(
              'workspace_draft_supported_loads',
              columns: ['load_kind'],
              where: 'draft_id = ?',
              whereArgs: [draftId],
              orderBy: 'load_kind ASC',
            ))
            .map(
              (row) => _loadKind(
                _string(row, 'load_kind', r'$.equipment.supportedLoads'),
              ),
            )
            .toSet();
    if (equipmentIds.isEmpty || supportedLoads.isEmpty) {
      throw _error(
        'equipment.incomplete_capabilities',
        r'$.equipment',
        'Equipment IDs and supported load kinds must be explicit.',
      );
    }
    if (supportedLoads.contains(LoadKind.externalWeight) && plates.isEmpty) {
      throw _error(
        'equipment.missing_plate_pair',
        r'$.equipment.availablePlates',
        'External loading requires at least one complete plate pair.',
      );
    }
    return EquipmentProfile(
      equipmentIds: equipmentIds,
      supportedLoads: supportedLoads,
      barWeight: _number(bar, 'weight', r'$.equipment.bar.weight'),
      availablePlates: plates,
    );
  }

  Future<AssistancePlan?> _loadAssistance(
    String draftId,
    CatalogSnapshot snapshot,
  ) async {
    final planRows = await database.query(
      'workspace_draft_assistance',
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
    if (planRows.isEmpty) return null;
    final plan = await _one(
      'workspace_draft_assistance',
      planRows,
      r'$.assistance',
    );
    final selectionRows = await database.query(
      'workspace_draft_assistance_selections',
      where: 'draft_id = ?',
      whereArgs: [draftId],
      orderBy: 'id ASC',
    );
    final selections = <WorkspaceAssistanceSelection>[];
    for (final row in selectionRows) {
      final selectionId = _string(row, 'id', r'$.assistance.selections.id');
      final prescriptions = await database.query(
        'workspace_draft_assistance_prescriptions',
        where: 'selection_id = ?',
        whereArgs: [selectionId],
        orderBy: 'phase ASC',
      );
      final byPhase = {
        for (final prescription in prescriptions)
          _string(prescription, 'phase', r'$.assistance.prescriptions.phase'):
              prescription,
      };
      final regularRow = byPhase['regular'];
      if (regularRow == null) {
        throw _error(
          'assistance.missing_regular',
          r'$.assistance.selections',
          'Every assistance selection needs a regular prescription.',
        );
      }
      final mode = _assistanceMode(
        _string(row, 'deload_mode', r'$.assistance.selections.deloadMode'),
      );
      final deloadRow = byPhase['deload'];
      if ((mode == AssistanceDeloadMode.custom) != (deloadRow != null)) {
        throw _error(
          'assistance.invalid_deload',
          r'$.assistance.selections.deload',
          'Only a custom deload requires exactly one deload prescription.',
        );
      }
      selections.add(
        WorkspaceAssistanceSelection(
          id: selectionId,
          slotId: CatalogId(
            _string(row, 'slot_id', r'$.assistance.selections.slotId'),
          ),
          movementId: CatalogId(
            _string(row, 'movement_id', r'$.assistance.selections.movementId'),
          ),
          regular: _prescription(
            regularRow,
            r'$.assistance.selections.regular',
          ),
          deloadMode: mode,
          deload: deloadRow == null
              ? null
              : _prescription(deloadRow, r'$.assistance.selections.deload'),
        ),
      );
    }
    return assistanceConfigurationPort.resolve(
      planId: CatalogId(
        _string(plan, 'assistance_plan_id', r'$.assistance.planId'),
      ),
      selections: List.unmodifiable(selections),
      snapshot: snapshot,
    );
  }

  Future<List<ConditioningConfiguration>> _loadConditioning(
    String draftId,
    CatalogSnapshot snapshot,
  ) async {
    final rows = await database.query(
      'workspace_draft_conditioning',
      where: 'draft_id = ?',
      whereArgs: [draftId],
      orderBy: 'sequence ASC',
    );
    final selections = <WorkspaceConditioningSelection>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final sequence = _integer(row, 'sequence', r'$.conditioning.sequence');
      if (sequence != index) {
        throw _error(
          'conditioning.non_contiguous_sequence',
          r'$.conditioning.sequence',
          'Conditioning sequence must start at zero and be contiguous.',
        );
      }
      selections.add(
        WorkspaceConditioningSelection(
          sequence: sequence,
          definitionId: CatalogId(
            _string(row, 'definition_id', r'$.conditioning.definitionId'),
          ),
          prescription: ConditioningPrescription(
            modality: _conditioningModality(
              _string(row, 'modality', r'$.conditioning.modality'),
            ),
            target: _nullableNumber(row, 'target', r'$.conditioning.target'),
            workSeconds: _nullableInteger(
              row,
              'work_seconds',
              r'$.conditioning.workSeconds',
            ),
            restSeconds: _nullableInteger(
              row,
              'rest_seconds',
              r'$.conditioning.restSeconds',
            ),
          ),
        ),
      );
    }
    if (selections.isEmpty) return const [];
    final resolved = await conditioningConfigurationPort.resolve(
      selections: List.unmodifiable(selections),
      snapshot: snapshot,
    );
    if (resolved.length != selections.length) {
      throw _error(
        'conditioning.resolution_mismatch',
        r'$.conditioning',
        'Every conditioning selection must resolve exactly once.',
      );
    }
    return List.unmodifiable(resolved);
  }

  SetPrescription _prescription(Map<String, Object?> row, String path) {
    final repetitionKind = _string(
      row,
      'repetition_kind',
      '$path.repetitions.kind',
    );
    final minimum = _nullableInteger(
      row,
      'repetition_minimum',
      '$path.repetitions.minimum',
    );
    final maximum = _nullableInteger(
      row,
      'repetition_maximum',
      '$path.repetitions.maximum',
    );
    final repetitions = switch (repetitionKind) {
      'fixed' when minimum != null && maximum == null => FixedRepetitions(
        minimum,
      ),
      'range' when minimum != null && maximum != null => RepetitionRange(
        minimum,
        maximum,
      ),
      'amrap' when maximum == null => Amrap(minimum: minimum),
      _ => throw _error(
        'assistance.invalid_repetitions',
        '$path.repetitions',
        'The structured repetition target is invalid.',
      ),
    };
    final kind = _loadKind(_string(row, 'load_kind', '$path.load.kind'));
    final value = _nullableNumber(row, 'load_value', '$path.load.value');
    final load = switch (kind) {
      LoadKind.none when value == null => const Unloaded(),
      LoadKind.bodyweight when value == null => const BodyweightLoad(),
      LoadKind.percentTrainingMax
          when value != null && value > 0 && value <= 1 =>
        PercentTrainingMax(value),
      LoadKind.percentOneRepMax when value != null && value > 0 && value <= 1 =>
        PercentOneRepMax(value),
      LoadKind.externalWeight ||
      LoadKind.machineSetting ||
      LoadKind.equipmentSetting ||
      LoadKind.assistedBodyweight ||
      LoadKind.addedBodyweightLoad when value != null => DirectLoad(
        value,
        kind,
      ),
      _ => throw _error(
        'assistance.invalid_load',
        '$path.load',
        'The structured load target is invalid.',
      ),
    };
    return SetPrescription(
      sets: _integer(row, 'sets', '$path.sets'),
      repetitions: repetitions,
      load: load,
    );
  }

  void _verifyEquipmentPayload(
    EquipmentProfile payload,
    EquipmentProfile stored,
  ) {
    if (!_sameSet(payload.equipmentIds, stored.equipmentIds) ||
        !_sameSet(payload.supportedLoads, stored.supportedLoads) ||
        !_sameNullableDouble(payload.barWeight, stored.barWeight) ||
        !_sameDoubleList(payload.availablePlates, stored.availablePlates)) {
      throw _error(
        'equipment.payload_mismatch',
        r'$.equipment',
        'The v1 payload and structured equipment selection differ.',
      );
    }
  }

  void _verifyAssistancePayload(
    AssistancePlan? payload,
    AssistancePlan? stored,
  ) {
    if (payload == null || stored == null) {
      if (payload != stored) {
        throw _error(
          'assistance.payload_mismatch',
          r'$.assistance',
          'The v1 payload and structured assistance selection differ.',
        );
      }
      return;
    }
    if (!_sameAssistance(payload, stored)) {
      throw _error(
        'assistance.payload_mismatch',
        r'$.assistance',
        'The v1 payload and catalog-resolved assistance selection differ.',
      );
    }
  }

  void _verifyConditioningPayload(
    List<WorkspaceConditioningDraft> payload,
    List<ConditioningConfiguration> stored,
  ) {
    if (payload.length != stored.length) {
      throw _error(
        'conditioning.payload_mismatch',
        r'$.conditioning',
        'The v1 payload and structured conditioning selections differ.',
      );
    }
    for (var index = 0; index < payload.length; index++) {
      if (payload[index].definitionId != stored[index].definition.id ||
          !_sameConditioning(
            payload[index].prescription,
            stored[index].prescription,
          )) {
        throw _error(
          'conditioning.payload_mismatch',
          r'$.conditioning',
          'The v1 payload and catalog-resolved conditioning selections differ.',
        );
      }
    }
  }

  Future<Map<String, Object?>> _one(
    String table,
    List<Map<String, Object?>> rows,
    String path,
  ) async {
    if (rows.length != 1) {
      throw _error(
        rows.isEmpty ? '$table.missing' : '$table.duplicate',
        path,
        'Expected exactly one $table row.',
      );
    }
    return rows.single;
  }
}

EngineRequestLoadException _error(
  String code,
  String path,
  String message, [
  Object? cause,
]) => EngineRequestLoadException(
  code: code,
  path: path,
  message: message,
  cause: cause,
);

String _string(Map<String, Object?> row, String key, String path) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty) {
    throw _error(
      'workspace.invalid_string',
      path,
      'Expected a non-empty string.',
    );
  }
  return value;
}

int _integer(Map<String, Object?> row, String key, String path) {
  final value = row[key];
  if (value is! int) {
    throw _error('workspace.invalid_integer', path, 'Expected an integer.');
  }
  return value;
}

int? _nullableInteger(Map<String, Object?> row, String key, String path) {
  if (row[key] == null) return null;
  return _integer(row, key, path);
}

double _number(Map<String, Object?> row, String key, String path) {
  final value = row[key];
  if (value is! num || !value.isFinite) {
    throw _error('workspace.invalid_number', path, 'Expected a finite number.');
  }
  return value.toDouble();
}

double? _nullableNumber(Map<String, Object?> row, String key, String path) {
  if (row[key] == null) return null;
  return _number(row, key, path);
}

WeightUnit _weightUnit(String value, String path) => switch (value) {
  'kg' => WeightUnit.kilograms,
  'lb' => WeightUnit.pounds,
  _ => throw _error('workspace.unknown_unit', path, 'Unknown weight unit.'),
};

String _storedUnit(WeightUnit unit) => switch (unit) {
  WeightUnit.kilograms => 'kg',
  WeightUnit.pounds => 'lb',
};

LoadKind _loadKind(String value) {
  for (final kind in LoadKind.values) {
    if (kind.name == value) return kind;
  }
  throw _error(
    'workspace.unknown_load_kind',
    r'$.load.kind',
    'Unknown load kind.',
  );
}

AssistanceDeloadMode _assistanceMode(String value) {
  for (final mode in AssistanceDeloadMode.values) {
    if (mode.name == value) return mode;
  }
  throw _error(
    'workspace.unknown_deload_mode',
    r'$.assistance.deloadMode',
    'Unknown assistance deload mode.',
  );
}

ConditioningModality _conditioningModality(String value) {
  for (final modality in ConditioningModality.values) {
    if (modality.name == value) return modality;
  }
  throw _error(
    'workspace.unknown_conditioning_modality',
    r'$.conditioning.modality',
    'Unknown conditioning modality.',
  );
}

bool _sameDouble(double left, double right) => (left - right).abs() <= 1e-9;

bool _sameNullableDouble(double? left, double? right) =>
    left == null || right == null ? left == right : _sameDouble(left, right);

bool _sameDoubleList(List<double> left, List<double> right) {
  if (left.length != right.length) return false;
  final a = [...left]..sort();
  final b = [...right]..sort();
  for (var index = 0; index < a.length; index++) {
    if (!_sameDouble(a[index], b[index])) return false;
  }
  return true;
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

bool _sameAssistance(AssistancePlan left, AssistancePlan right) {
  if (left.slots.length != right.slots.length ||
      left.selections.length != right.selections.length) {
    return false;
  }
  final rightSlots = {for (final slot in right.slots) slot.id: slot};
  for (final slot in left.slots) {
    final other = rightSlots[slot.id];
    if (other == null ||
        slot.roleId != other.roleId ||
        slot.minimumSelections != other.minimumSelections ||
        slot.maximumSelections != other.maximumSelections ||
        !_sameSet(slot.movementIds, other.movementIds)) {
      return false;
    }
  }
  final remaining = [...right.selections];
  for (final selection in left.selections) {
    final index = remaining.indexWhere(
      (other) =>
          selection.slotId == other.slotId &&
          selection.movementId == other.movementId &&
          selection.deloadMode == other.deloadMode &&
          _samePrescription(selection.regular, other.regular) &&
          _sameNullablePrescription(selection.deload, other.deload),
    );
    if (index < 0) return false;
    remaining.removeAt(index);
  }
  return remaining.isEmpty;
}

bool _sameNullablePrescription(SetPrescription? left, SetPrescription? right) =>
    left == null || right == null
    ? left == right
    : _samePrescription(left, right);

bool _samePrescription(SetPrescription left, SetPrescription right) =>
    left.sets == right.sets &&
    _sameRepetitions(left.repetitions, right.repetitions) &&
    _sameLoad(left.load, right.load);

bool _sameRepetitions(RepetitionTarget left, RepetitionTarget right) =>
    switch ((left, right)) {
      (FixedRepetitions(count: final a), FixedRepetitions(count: final b)) =>
        a == b,
      (
        RepetitionRange(minimum: final a, maximum: final b),
        RepetitionRange(minimum: final c, maximum: final d),
      ) =>
        a == c && b == d,
      (Amrap(minimum: final a), Amrap(minimum: final b)) => a == b,
      _ => false,
    };

bool _sameLoad(LoadTarget left, LoadTarget right) {
  if (left.kind != right.kind) return false;
  return switch ((left, right)) {
    (
      PercentTrainingMax(percent: final a),
      PercentTrainingMax(percent: final b),
    ) =>
      _sameDouble(a, b),
    (PercentOneRepMax(percent: final a), PercentOneRepMax(percent: final b)) =>
      _sameDouble(a, b),
    (DirectLoad(amount: final a), DirectLoad(amount: final b)) => _sameDouble(
      a,
      b,
    ),
    _ => true,
  };
}

bool _sameConditioning(
  ConditioningPrescription left,
  ConditioningPrescription right,
) =>
    left.modality == right.modality &&
    _sameNullableDouble(left.target, right.target) &&
    left.workSeconds == right.workSeconds &&
    left.restSeconds == right.restSeconds;
