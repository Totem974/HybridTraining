import 'package:sqflite/sqflite.dart';

/// Schema of catalog.db. Runtime consumers open this database read-only.
abstract final class CatalogDatabaseSchema {
  static const version = 2;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE catalog_versions (
      id TEXT PRIMARY KEY, ordinal INTEGER NOT NULL UNIQUE CHECK(ordinal > 0),
      status TEXT NOT NULL CHECK(status IN ('draft','inReview','approved','published','retired','rejected')),
      parent_version_id TEXT, content_hash TEXT NOT NULL UNIQUE,
      canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version > 0),
      signature TEXT, signature_key_id TEXT, signature_algorithm TEXT,
      signature_verified INTEGER NOT NULL DEFAULT 0 CHECK(signature_verified IN (0,1)),
      trust_channel TEXT NOT NULL CHECK(trust_channel IN ('localReview','bundled','signedRemote')),
      created_at TEXT NOT NULL, published_at TEXT, retired_at TEXT,
      CHECK((status IN ('draft','inReview','approved','rejected') AND published_at IS NULL AND retired_at IS NULL) OR
        (status='published' AND published_at IS NOT NULL AND retired_at IS NULL) OR
        (status='retired' AND published_at IS NOT NULL AND retired_at IS NOT NULL)),
      CHECK(signature IS NULL OR (signature_key_id IS NOT NULL AND signature_algorithm IS NOT NULL)),
      FOREIGN KEY(parent_version_id) REFERENCES catalog_versions(id)
    )''');
    await db.execute('''CREATE TABLE catalog_publication_validations (
      catalog_version_id TEXT PRIMARY KEY, validated_content_hash TEXT NOT NULL,
      evidence_valid INTEGER NOT NULL CHECK(evidence_valid=1), licences_valid INTEGER NOT NULL CHECK(licences_valid=1),
      dependencies_valid INTEGER NOT NULL CHECK(dependencies_valid=1), children_valid INTEGER NOT NULL CHECK(children_valid=1),
      blockers_clear INTEGER NOT NULL CHECK(blockers_clear=1), signature_valid INTEGER NOT NULL CHECK(signature_valid IN (0,1)),
      validated_at TEXT NOT NULL, FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id)
    )''');
    await _createAdministrationStaging(db);
    await db.execute('''CREATE TABLE books (
      id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT,
      license_status TEXT NOT NULL CHECK(license_status IN ('ownedReference','compatible','unknown','restricted'))
    )''');
    await db.execute('''CREATE TABLE editions (
      id TEXT PRIMARY KEY, book_id TEXT NOT NULL, label TEXT NOT NULL,
      publication_year INTEGER CHECK(publication_year > 0), digest TEXT,
      FOREIGN KEY(book_id) REFERENCES books(id), UNIQUE(book_id,label)
    )''');
    await db.execute('''CREATE TABLE sources (
      id TEXT PRIMARY KEY, edition_id TEXT, revision INTEGER NOT NULL CHECK(revision > 0), kind TEXT NOT NULL CHECK(kind IN ('book','reviewedRepository','blackBox','licenseAudit')),
      locator TEXT NOT NULL, note TEXT NOT NULL DEFAULT '', FOREIGN KEY(edition_id) REFERENCES editions(id)
    )''');
    await db.execute('''CREATE TABLE catalog_entries (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL,
      catalog_entry_key TEXT NOT NULL,
      stable_domain_id TEXT NOT NULL CHECK(stable_domain_id = lower(stable_domain_id)
        AND length(stable_domain_id)>0 AND stable_domain_id NOT GLOB '*[^a-z0-9-]*'
        AND stable_domain_id NOT LIKE '-%' AND stable_domain_id NOT LIKE '%-'
        AND stable_domain_id NOT LIKE '%--%'),
      nature TEXT NOT NULL CHECK(nature IN ('cycleDefinition','schedule','policy','component','assistancePlan','finiteProgram','phase','resource','protocol','transition','outOfScope','other')),
      authority TEXT NOT NULL CHECK(authority IN ('canonical','compatible','userCustom')),
      review_status TEXT NOT NULL CHECK(review_status IN ('needsReview','confirmed','rejected')),
      implementation_status TEXT NOT NULL CHECK(implementation_status IN ('notStarted','partial','implemented','blocked')),
      execution_status TEXT NOT NULL CHECK(execution_status IN ('supported','executable','blocked')),
      product_surface TEXT NOT NULL CHECK(product_surface IN ('cycle','forever','shared','none')),
      visibility TEXT NOT NULL CHECK(visibility IN ('hidden','internal','visible')),
      license_status TEXT NOT NULL CHECK(license_status IN ('ownedReference','compatible','unknown','restricted')),
      CHECK(catalog_entry_key GLOB '[A-Z][A-Z0-9]*-[0-9][0-9][0-9]*'),
      CHECK(review_status = 'confirmed' OR visibility != 'visible'),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      UNIQUE(catalog_version_id,catalog_entry_key), UNIQUE(catalog_version_id,stable_domain_id)
    )''');
    await db.execute('''CREATE TABLE catalog_entry_relations (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, from_entry_id TEXT NOT NULL, to_entry_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('parent','child','alias','dependency','supersedes')),
      CHECK(from_entry_id != to_entry_id), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(from_entry_id) REFERENCES catalog_entries(id), FOREIGN KEY(to_entry_id) REFERENCES catalog_entries(id),
      UNIQUE(catalog_version_id,from_entry_id,to_entry_id,kind)
    )''');
    await db.execute('''CREATE TABLE evidence (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, source_id TEXT NOT NULL,
      rule_id TEXT NOT NULL CHECK(rule_id = lower(rule_id) AND length(rule_id)>0
        AND rule_id NOT GLOB '*[^a-z0-9-]*' AND rule_id NOT LIKE '-%'
        AND rule_id NOT LIKE '%-' AND rule_id NOT LIKE '%--%'),
      subject_type TEXT NOT NULL CHECK(subject_type IN ('catalogEntry','template','variant','moduleVersion','rule','schedule','finiteProgram','movement','assistancePlan','policy')), subject_id TEXT NOT NULL,
      review_status TEXT NOT NULL CHECK(review_status IN ('needsReview','confirmed','rejected')),
      excerpt_digest TEXT, note TEXT NOT NULL DEFAULT '',
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(source_id) REFERENCES sources(id),
      UNIQUE(catalog_version_id,source_id,subject_type,subject_id)
    )''');
    await db.execute('''CREATE TABLE modules (
      id TEXT PRIMARY KEY, stable_key TEXT NOT NULL UNIQUE,
      kind TEXT NOT NULL CHECK(kind IN ('main','supplemental','assistance','warmup','deload','joker','conditioning','schedule','other'))
    )''');
    await db.execute('''CREATE TABLE module_versions (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, catalog_entry_id TEXT NOT NULL, module_id TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK(revision > 0), definition_json TEXT NOT NULL,
      review_status TEXT NOT NULL CHECK(review_status IN ('needsReview','confirmed','rejected')),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(catalog_entry_id) REFERENCES catalog_entries(id),
      FOREIGN KEY(module_id) REFERENCES modules(id),
      UNIQUE(catalog_version_id,module_id,revision)
    )''');
    await db.execute('''CREATE TABLE templates (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, catalog_entry_id TEXT NOT NULL, stable_key TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK(revision > 0),
      kind TEXT NOT NULL CHECK(kind IN ('cycle','finiteProgram','phase','resource')),
      name_key TEXT NOT NULL, FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(catalog_entry_id) REFERENCES catalog_entries(id),
      UNIQUE(catalog_version_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE variants (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, template_id TEXT NOT NULL, stable_key TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('supported','executable','blocked')), blocker_code TEXT,
      CHECK((status='blocked')=(blocker_code IS NOT NULL)),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(template_id) REFERENCES templates(id),
      UNIQUE(template_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE engine_bindings (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      engine_kind TEXT NOT NULL CHECK(engine_kind IN ('legacyCanonical','cycleV5','forever')),
      engine_id TEXT NOT NULL, definition_id TEXT NOT NULL, definition_revision INTEGER NOT NULL CHECK(definition_revision > 0),
      status TEXT NOT NULL CHECK(status IN ('supported','executable','blocked')), blocker_code TEXT,
      CHECK((status='blocked')=(blocker_code IS NOT NULL)), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(variant_id) REFERENCES variants(id), UNIQUE(variant_id,engine_kind,engine_id)
    )''');
    await db.execute('''CREATE TABLE engine_binding_variants (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, engine_binding_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('supported','executable','blocked')), blocker_code TEXT,
      CHECK((status='blocked')=(blocker_code IS NOT NULL)), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(engine_binding_id) REFERENCES engine_bindings(id), FOREIGN KEY(variant_id) REFERENCES variants(id),
      UNIQUE(engine_binding_id,variant_id)
    )''');
    await db.execute('''CREATE TABLE engine_binding_capabilities (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, engine_binding_id TEXT NOT NULL, capability_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(engine_binding_id) REFERENCES engine_bindings(id),
      UNIQUE(engine_binding_id,capability_id)
    )''');
    await db.execute('''CREATE TABLE engine_binding_schedules (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, engine_binding_id TEXT NOT NULL, schedule_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(engine_binding_id) REFERENCES engine_bindings(id),
      FOREIGN KEY(schedule_id) REFERENCES schedules(id), UNIQUE(engine_binding_id,schedule_id)
    )''');
    await db.execute('''CREATE TABLE engine_binding_options (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, engine_binding_id TEXT NOT NULL, option_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(engine_binding_id) REFERENCES engine_bindings(id),
      UNIQUE(engine_binding_id,option_id)
    )''');
    await db.execute('''CREATE TABLE engine_binding_migration_aliases (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, engine_binding_id TEXT NOT NULL, alias TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(engine_binding_id) REFERENCES engine_bindings(id),
      UNIQUE(engine_binding_id,alias)
    )''');
    await db.execute('''CREATE TABLE parameter_schemas (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      schema_version INTEGER NOT NULL CHECK(schema_version > 0), schema_json TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(variant_id) REFERENCES variants(id),
      UNIQUE(variant_id,schema_version)
    )''');
    await db.execute('''CREATE TABLE variant_module_bindings (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL, module_version_id TEXT NOT NULL,
      role TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence >= 0), configuration_json TEXT NOT NULL DEFAULT '{}',
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(variant_id) REFERENCES variants(id),
      FOREIGN KEY(module_version_id) REFERENCES module_versions(id), UNIQUE(variant_id,role,sequence)
    )''');
    await db.execute('''CREATE TABLE declarative_rules (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL,
      owner_type TEXT NOT NULL CHECK(owner_type IN ('catalogEntry','template','variant','moduleVersion','schedule','finiteProgram','movement','assistancePlan','policy')),
      owner_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('compatibility','visibility','required','constraint')),
      expression_json TEXT NOT NULL CHECK(json_valid(expression_json)), blocker_code TEXT,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id)
    )''');
    await db.execute('''CREATE TABLE finite_programs (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, template_id TEXT NOT NULL,
      stable_key TEXT NOT NULL, FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(template_id) REFERENCES templates(id), UNIQUE(template_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE finite_program_phases (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, finite_program_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), role TEXT NOT NULL CHECK(role IN ('prep','leader','anchor','transition','deload','test','custom')),
      repetitions INTEGER NOT NULL CHECK(repetitions > 0), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(finite_program_id) REFERENCES finite_programs(id), UNIQUE(finite_program_id,sequence)
    )''');
    await db.execute('''CREATE TABLE finite_program_segments (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, phase_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), variant_id TEXT NOT NULL, schedule_id TEXT,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(phase_id) REFERENCES finite_program_phases(id),
      FOREIGN KEY(variant_id) REFERENCES variants(id), FOREIGN KEY(schedule_id) REFERENCES schedules(id), UNIQUE(phase_id,sequence)
    )''');
    await db.execute('''CREATE TABLE finite_program_transitions (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, from_phase_id TEXT NOT NULL, to_phase_id TEXT,
      movement_id TEXT, kind TEXT NOT NULL CHECK(kind IN ('keep','add','multiply','testThenSet')),
      amount REAL, rule_json TEXT NOT NULL DEFAULT '{}', CHECK((kind IN ('add','multiply'))=(amount IS NOT NULL)),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(from_phase_id) REFERENCES finite_program_phases(id),
      FOREIGN KEY(to_phase_id) REFERENCES finite_program_phases(id), FOREIGN KEY(movement_id) REFERENCES movements(id),
      UNIQUE(from_phase_id,to_phase_id,movement_id)
    )''');
    await db.execute('''CREATE TABLE schedules (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL, stable_key TEXT NOT NULL,
      duration_weeks INTEGER NOT NULL CHECK(duration_weeks > 0), days_per_week INTEGER NOT NULL CHECK(days_per_week BETWEEN 1 AND 7),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(variant_id) REFERENCES variants(id), UNIQUE(variant_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE schedule_weeks (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, schedule_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), role TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(schedule_id) REFERENCES schedules(id), UNIQUE(schedule_id,sequence)
    )''');
    await db.execute('''CREATE TABLE schedule_segments (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, schedule_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), kind TEXT NOT NULL CHECK(kind IN ('training','deload','test','recovery','custom')),
      start_offset_days INTEGER NOT NULL CHECK(start_offset_days >= 0), duration_days INTEGER NOT NULL CHECK(duration_days > 0),
      frequency INTEGER NOT NULL CHECK(frequency > 0), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(schedule_id) REFERENCES schedules(id), UNIQUE(schedule_id,sequence)
    )''');
    await db.execute('''CREATE TABLE schedule_segment_roles (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, segment_id TEXT NOT NULL, role_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(segment_id) REFERENCES schedule_segments(id),
      UNIQUE(segment_id,role_id)
    )''');
    await db.execute('''CREATE TABLE schedule_training_max_evolution (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, schedule_id TEXT NOT NULL, movement_id TEXT NOT NULL,
      effective_offset_days INTEGER NOT NULL CHECK(effective_offset_days >= 0), training_max REAL NOT NULL CHECK(training_max > 0),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(schedule_id) REFERENCES schedules(id),
      FOREIGN KEY(movement_id) REFERENCES movements(id),
      UNIQUE(schedule_id,movement_id,effective_offset_days)
    )''');
    await db.execute('''CREATE TABLE schedule_sessions (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, week_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), weekday INTEGER NOT NULL CHECK(weekday BETWEEN 1 AND 7), role TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(week_id) REFERENCES schedule_weeks(id),
      UNIQUE(week_id,sequence), UNIQUE(week_id,weekday)
    )''');
    await db.execute('''CREATE TABLE session_blocks (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, session_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), kind TEXT NOT NULL CHECK(kind IN ('warmup','main','supplemental','assistance','conditioning','joker','deload')),
      module_version_id TEXT, FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(session_id) REFERENCES schedule_sessions(id), FOREIGN KEY(module_version_id) REFERENCES module_versions(id), UNIQUE(session_id,sequence)
    )''');
    await db.execute('''CREATE TABLE movement_categories (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, stable_key TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), UNIQUE(catalog_version_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE equipment (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, stable_key TEXT NOT NULL, kind TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), UNIQUE(catalog_version_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE movements (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, catalog_entry_id TEXT NOT NULL, stable_key TEXT NOT NULL, category_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('mainLift','exercise','conditioning','activity')),
      body_region TEXT NOT NULL CHECK(body_region IN ('upper','lower','fullBody','conditioning')),
      load_compatibility_json TEXT NOT NULL DEFAULT '[]',
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(catalog_entry_id) REFERENCES catalog_entries(id),
      FOREIGN KEY(category_id) REFERENCES movement_categories(id),
      UNIQUE(catalog_version_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE movement_capabilities (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, movement_id TEXT NOT NULL, capability_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(movement_id) REFERENCES movements(id),
      UNIQUE(movement_id,capability_id)
    )''');
    await db.execute('''CREATE TABLE conditioning_definitions (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, movement_id TEXT NOT NULL UNIQUE,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(movement_id) REFERENCES movements(id)
    )''');
    await db.execute('''CREATE TABLE conditioning_modalities (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, conditioning_definition_id TEXT NOT NULL,
      modality TEXT NOT NULL CHECK(modality IN ('time','distance','repetitions','intervals','open')),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(conditioning_definition_id) REFERENCES conditioning_definitions(id), UNIQUE(conditioning_definition_id,modality)
    )''');
    await db.execute('''CREATE TABLE movement_equipment (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, movement_id TEXT NOT NULL, equipment_id TEXT NOT NULL,
      required INTEGER NOT NULL CHECK(required IN (0,1)), FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(movement_id) REFERENCES movements(id), FOREIGN KEY(equipment_id) REFERENCES equipment(id), UNIQUE(movement_id,equipment_id)
    )''');
    await db.execute('''CREATE TABLE prescriptions (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, block_id TEXT NOT NULL, movement_id TEXT NOT NULL,
      sequence INTEGER NOT NULL CHECK(sequence >= 0), kind TEXT NOT NULL CHECK(kind IN ('straightSets','fiveThreeOne','totalRepetitions','duration','distance','rounds','completion','qualitative')),
      repetition_target_kind TEXT NOT NULL CHECK(repetition_target_kind IN ('fixed','amrap','range','none')),
      load_kind TEXT NOT NULL CHECK(load_kind IN ('none','externalWeight','machineSetting','equipmentSetting','bodyweight','assistedBodyweight','addedBodyweightLoad','percentTrainingMax','percentOneRepMax')),
      prescription_json TEXT NOT NULL, FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(block_id) REFERENCES session_blocks(id), FOREIGN KEY(movement_id) REFERENCES movements(id), UNIQUE(block_id,sequence)
    )''');
    await db.execute('''CREATE TABLE assistance_plans (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL, stable_key TEXT NOT NULL,
      deload_mode TEXT NOT NULL CHECK(deload_mode IN ('templateDefault','inheritRegular','custom','omit')),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(variant_id) REFERENCES variants(id), UNIQUE(variant_id,stable_key)
    )''');
    await db.execute('''CREATE TABLE assistance_slots (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, assistance_plan_id TEXT NOT NULL,
      session_role TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence >= 0), category_id TEXT,
      minimum_selections INTEGER NOT NULL CHECK(minimum_selections >= 0),
      maximum_selections INTEGER NOT NULL CHECK(maximum_selections >= minimum_selections), prescription_json TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(assistance_plan_id) REFERENCES assistance_plans(id),
      FOREIGN KEY(category_id) REFERENCES movement_categories(id), UNIQUE(assistance_plan_id,session_role,sequence)
    )''');
    await db.execute('''CREATE TABLE assistance_slot_movements (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, assistance_slot_id TEXT NOT NULL, movement_id TEXT NOT NULL,
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(assistance_slot_id) REFERENCES assistance_slots(id),
      FOREIGN KEY(movement_id) REFERENCES movements(id), UNIQUE(assistance_slot_id,movement_id)
    )''');
    await db.execute('''CREATE TABLE policies (
      id TEXT PRIMARY KEY, catalog_version_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('warmup','joker','mainDeload','assistanceDeload','trainingMaxProgression','conditioning')),
      policy_json TEXT NOT NULL, review_status TEXT NOT NULL CHECK(review_status IN ('needsReview','confirmed','rejected')),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id), FOREIGN KEY(variant_id) REFERENCES variants(id), UNIQUE(variant_id,kind)
    )''');
    for (final table in _versionedTables) {
      await db.execute(
        'CREATE INDEX ${table}_catalog_version_idx ON $table(catalog_version_id)',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_immutable_insert BEFORE INSERT ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=NEW.catalog_version_id) IN ('published','retired')
        BEGIN SELECT RAISE(ABORT,'published catalog is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_immutable_update BEFORE UPDATE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id) IN ('published','retired')
          OR (SELECT status FROM catalog_versions WHERE id=NEW.catalog_version_id) IN ('published','retired')
        BEGIN SELECT RAISE(ABORT,'published catalog is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_version_identity BEFORE UPDATE OF catalog_version_id ON $table
        WHEN OLD.catalog_version_id != NEW.catalog_version_id
        BEGIN SELECT RAISE(ABORT,'catalog version identity is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_immutable_delete BEFORE DELETE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id) IN ('published','retired')
        BEGIN SELECT RAISE(ABORT,'published catalog is immutable'); END''',
      );
    }
    await _createReferencedDefinitionImmutability(db);
    await db.execute(
      'CREATE INDEX evidence_subject_idx ON evidence(subject_type,subject_id)',
    );
    await db.execute(
      'CREATE INDEX rules_owner_idx ON declarative_rules(owner_type,owner_id)',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_version_lifecycle BEFORE UPDATE OF status ON catalog_versions
      WHEN NOT (
        (OLD.status='draft' AND NEW.status IN ('inReview','rejected')) OR
        (OLD.status='inReview' AND NEW.status IN ('draft','approved','rejected')) OR
        (OLD.status='approved' AND NEW.status IN ('inReview','published','rejected')) OR
        (OLD.status='published' AND NEW.status='retired') OR
        (OLD.status='rejected' AND NEW.status='draft')
      ) BEGIN SELECT RAISE(ABORT,'invalid catalog lifecycle transition'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_version_published_fields BEFORE UPDATE ON catalog_versions
      WHEN OLD.status IN ('published','retired') AND (
        OLD.content_hash != NEW.content_hash OR OLD.canonicalization_version != NEW.canonicalization_version OR
        OLD.signature IS NOT NEW.signature OR OLD.signature_key_id IS NOT NEW.signature_key_id OR
        OLD.signature_algorithm IS NOT NEW.signature_algorithm OR
        OLD.signature_verified != NEW.signature_verified OR OLD.trust_channel != NEW.trust_channel OR
        OLD.ordinal != NEW.ordinal OR OLD.parent_version_id IS NOT NEW.parent_version_id
      ) BEGIN SELECT RAISE(ABORT,'published catalog metadata is immutable'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_publication_receipt_update BEFORE UPDATE ON catalog_publication_validations
      WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id) IN ('published','retired')
      BEGIN SELECT RAISE(ABORT,'publication receipt is immutable'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_publication_receipt_delete BEFORE DELETE ON catalog_publication_validations
      WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id) IN ('published','retired')
      BEGIN SELECT RAISE(ABORT,'publication receipt is immutable'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_version_publication_gate BEFORE UPDATE OF status ON catalog_versions
      WHEN NEW.status='published' AND NOT EXISTS (
        SELECT 1 FROM catalog_publication_validations p WHERE p.catalog_version_id=OLD.id
          AND p.validated_content_hash=NEW.content_hash
          AND (NEW.signature IS NULL OR (p.signature_valid=1 AND NEW.signature_verified=1))
      ) BEGIN SELECT RAISE(ABORT,'catalog publication validation is required'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_relations_acyclic_insert BEFORE INSERT ON catalog_entry_relations
      WHEN EXISTS (WITH RECURSIVE reachable(id) AS (
        VALUES(NEW.to_entry_id) UNION SELECT r.to_entry_id FROM catalog_entry_relations r JOIN reachable p ON r.from_entry_id=p.id
      ) SELECT 1 FROM reachable WHERE id=NEW.from_entry_id)
      BEGIN SELECT RAISE(ABORT,'catalog relations must be acyclic'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_relations_acyclic_update BEFORE UPDATE OF from_entry_id,to_entry_id ON catalog_entry_relations
      WHEN EXISTS (WITH RECURSIVE reachable(id) AS (
        VALUES(NEW.to_entry_id) UNION SELECT r.to_entry_id FROM catalog_entry_relations r JOIN reachable p ON r.from_entry_id=p.id WHERE r.id!=OLD.id
      ) SELECT 1 FROM reachable WHERE id=NEW.from_entry_id)
      BEGIN SELECT RAISE(ABORT,'catalog relations must be acyclic'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER engine_binding_revision_insert BEFORE INSERT ON engine_bindings
      WHEN NEW.definition_revision != (
        SELECT t.revision FROM variants v JOIN templates t ON t.id=v.template_id WHERE v.id=NEW.variant_id
      ) BEGIN SELECT RAISE(ABORT,'engine binding revision must match template revision'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER engine_binding_revision_update BEFORE UPDATE OF definition_revision,variant_id ON engine_bindings
      WHEN NEW.definition_revision != (
        SELECT t.revision FROM variants v JOIN templates t ON t.id=v.template_id WHERE v.id=NEW.variant_id
      ) BEGIN SELECT RAISE(ABORT,'engine binding revision must match template revision'); END''',
    );
    await db.execute('''CREATE VIEW runtime_catalog_entries AS
      WITH RECURSIVE dependencies(root_id,dependency_id) AS (
        SELECT from_entry_id,to_entry_id FROM catalog_entry_relations WHERE kind='dependency'
        UNION
        SELECT d.root_id,r.to_entry_id FROM dependencies d JOIN catalog_entry_relations r ON r.from_entry_id=d.dependency_id
          WHERE r.kind='dependency'
      )
      SELECT e.* FROM catalog_entries e
      JOIN catalog_versions v ON v.id=e.catalog_version_id
      WHERE v.status='published' AND e.review_status='confirmed'
        AND (v.trust_channel!='signedRemote' OR v.signature_verified=1)
        AND e.implementation_status='implemented' AND e.execution_status='executable'
        AND e.visibility='visible' AND e.license_status IN ('ownedReference','compatible')
        AND EXISTS (SELECT 1 FROM evidence ev WHERE ev.catalog_version_id=e.catalog_version_id
          AND ev.subject_id=e.id AND ev.review_status='confirmed')
        AND EXISTS (SELECT 1 FROM templates t JOIN variants va ON va.template_id=t.id
          JOIN engine_bindings b ON b.variant_id=va.id
          WHERE t.catalog_entry_id=e.id AND t.catalog_version_id=e.catalog_version_id AND b.status='executable')
        AND NOT EXISTS (SELECT 1 FROM templates t WHERE t.catalog_entry_id=e.id AND NOT EXISTS (
          SELECT 1 FROM evidence ev WHERE ev.catalog_version_id=e.catalog_version_id
            AND ev.subject_type='template' AND ev.subject_id=t.id AND ev.review_status='confirmed'))
        AND NOT EXISTS (SELECT 1 FROM module_versions mv WHERE mv.catalog_entry_id=e.id AND NOT EXISTS (
          SELECT 1 FROM evidence ev WHERE ev.catalog_version_id=e.catalog_version_id
            AND ev.subject_type='moduleVersion' AND ev.subject_id=mv.id AND ev.review_status='confirmed'))
        AND NOT EXISTS (SELECT 1 FROM movements m WHERE m.catalog_entry_id=e.id AND NOT EXISTS (
          SELECT 1 FROM evidence ev WHERE ev.catalog_version_id=e.catalog_version_id
            AND ev.subject_type='movement' AND ev.subject_id=m.id AND ev.review_status='confirmed'))
        AND NOT EXISTS (SELECT 1 FROM templates t JOIN variants va ON va.template_id=t.id
          JOIN variant_module_bindings mb ON mb.variant_id=va.id JOIN module_versions mv ON mv.id=mb.module_version_id
          WHERE t.catalog_entry_id=e.id AND mv.review_status!='confirmed')
        AND NOT EXISTS (SELECT 1 FROM templates t JOIN variants va ON va.template_id=t.id
          JOIN policies p ON p.variant_id=va.id WHERE t.catalog_entry_id=e.id AND p.review_status!='confirmed')
        AND NOT EXISTS (SELECT 1 FROM dependencies r JOIN catalog_entries d ON d.id=r.dependency_id
          WHERE r.root_id=e.id AND
            (d.review_status!='confirmed' OR d.implementation_status!='implemented' OR d.execution_status='blocked'
             OR d.license_status NOT IN ('ownedReference','compatible')))''');
    await _createSameVersionGuards(db);
    await _createCatalogIdGuards(db);
  }

  static Future<void> _createReferencedDefinitionImmutability(
    DatabaseExecutor db,
  ) async {
    const guards = <(String, String)>[
      (
        'sources',
        "EXISTS (SELECT 1 FROM evidence e JOIN catalog_versions v ON v.id=e.catalog_version_id WHERE e.source_id=OLD.id AND v.status IN ('published','retired'))",
      ),
      (
        'editions',
        "EXISTS (SELECT 1 FROM sources s JOIN evidence e ON e.source_id=s.id JOIN catalog_versions v ON v.id=e.catalog_version_id WHERE s.edition_id=OLD.id AND v.status IN ('published','retired'))",
      ),
      (
        'books',
        "EXISTS (SELECT 1 FROM editions d JOIN sources s ON s.edition_id=d.id JOIN evidence e ON e.source_id=s.id JOIN catalog_versions v ON v.id=e.catalog_version_id WHERE d.book_id=OLD.id AND v.status IN ('published','retired'))",
      ),
      (
        'modules',
        "EXISTS (SELECT 1 FROM module_versions mv JOIN catalog_versions v ON v.id=mv.catalog_version_id WHERE mv.module_id=OLD.id AND v.status IN ('published','retired'))",
      ),
    ];
    for (final (table, referencedByPublished) in guards) {
      for (final operation in const ['UPDATE', 'DELETE']) {
        await db.execute(
          '''CREATE TRIGGER ${table}_published_reference_${operation.toLowerCase()}
          BEFORE $operation ON $table WHEN $referencedByPublished
          BEGIN SELECT RAISE(ABORT,'published catalog reference is immutable'); END''',
        );
      }
    }
  }

  static Future<void> _createAdministrationStaging(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE catalog_staging_entries (
      catalog_version_id TEXT NOT NULL,
      catalog_entry_key TEXT NOT NULL,
      canonical_record_json TEXT NOT NULL CHECK(json_valid(canonical_record_json)),
      record_hash TEXT NOT NULL CHECK(length(record_hash)>0),
      manifest_hash TEXT NOT NULL CHECK(length(manifest_hash)>0),
      stable_domain_id TEXT CHECK(stable_domain_id IS NULL OR (
        stable_domain_id = lower(stable_domain_id)
        AND length(stable_domain_id)>0
        AND stable_domain_id NOT GLOB '*[^a-z0-9-]*'
        AND stable_domain_id NOT LIKE '-%'
        AND stable_domain_id NOT LIKE '%-'
        AND stable_domain_id NOT LIKE '%--%')),
      authority TEXT CHECK(authority IS NULL OR authority IN ('canonical','compatible','userCustom')),
      review_status TEXT NOT NULL CHECK(review_status IN ('needsReview','confirmed','rejected')),
      visibility TEXT NOT NULL CHECK(visibility IN ('hidden','internal','visible')),
      execution_status TEXT NOT NULL CHECK(execution_status IN ('supported','executable','blocked')),
      CHECK(catalog_entry_key GLOB '[A-Z][A-Z0-9]*-[0-9][0-9][0-9]*'),
      CHECK(review_status = 'confirmed' OR visibility != 'visible'),
      CHECK(review_status = 'confirmed' OR execution_status != 'executable'),
      PRIMARY KEY(catalog_version_id,catalog_entry_key),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id)
    )''');
    await db.execute('''CREATE TABLE catalog_import_blockers (
      id TEXT PRIMARY KEY,
      catalog_version_id TEXT NOT NULL,
      catalog_entry_key TEXT,
      issue_code TEXT NOT NULL CHECK(length(issue_code)>0),
      severity TEXT NOT NULL CHECK(severity IN ('info','warning','publishBlocker','error')),
      message TEXT NOT NULL CHECK(length(message)>0),
      FOREIGN KEY(catalog_version_id) REFERENCES catalog_versions(id),
      FOREIGN KEY(catalog_version_id,catalog_entry_key)
        REFERENCES catalog_staging_entries(catalog_version_id,catalog_entry_key)
        ON DELETE CASCADE
    )''');
    await db.execute(
      'CREATE INDEX catalog_staging_entries_manifest_idx '
      'ON catalog_staging_entries(manifest_hash)',
    );
    await db.execute(
      'CREATE INDEX catalog_import_blockers_version_idx '
      'ON catalog_import_blockers(catalog_version_id,catalog_entry_key)',
    );
    for (final table in const [
      'catalog_staging_entries',
      'catalog_import_blockers',
    ]) {
      await db.execute(
        '''CREATE TRIGGER ${table}_draft_only_insert BEFORE INSERT ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=NEW.catalog_version_id)
          NOT IN ('draft','inReview')
        BEGIN SELECT RAISE(ABORT,'administration staging requires a draft or in-review version'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_draft_only_update BEFORE UPDATE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id)
          NOT IN ('draft','inReview')
          OR (SELECT status FROM catalog_versions WHERE id=NEW.catalog_version_id)
          NOT IN ('draft','inReview')
        BEGIN SELECT RAISE(ABORT,'administration staging requires a draft or in-review version'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_version_identity BEFORE UPDATE OF catalog_version_id ON $table
        WHEN OLD.catalog_version_id != NEW.catalog_version_id
        BEGIN SELECT RAISE(ABORT,'catalog version identity is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_published_delete BEFORE DELETE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE id=OLD.catalog_version_id)
          IN ('published','retired')
        BEGIN SELECT RAISE(ABORT,'published administration history is immutable'); END''',
      );
    }
    await db.execute(
      '''CREATE TRIGGER catalog_staging_manifest_insert BEFORE INSERT ON catalog_staging_entries
      WHEN NEW.manifest_hash != (
        SELECT content_hash FROM catalog_versions WHERE id=NEW.catalog_version_id
      ) BEGIN SELECT RAISE(ABORT,'staged manifest hash must match catalog version'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_staging_manifest_update BEFORE UPDATE OF manifest_hash ON catalog_staging_entries
      WHEN NEW.manifest_hash != (
        SELECT content_hash FROM catalog_versions WHERE id=NEW.catalog_version_id
      ) BEGIN SELECT RAISE(ABORT,'staged manifest hash must match catalog version'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_staging_promotion_gate BEFORE UPDATE OF status ON catalog_versions
      WHEN NEW.status IN ('approved','published') AND (
        EXISTS (
          SELECT 1 FROM catalog_staging_entries s WHERE s.catalog_version_id=OLD.id
        ) OR EXISTS (
          SELECT 1 FROM catalog_import_blockers b
          WHERE b.catalog_version_id=OLD.id AND b.severity IN ('publishBlocker','error')
        )
      ) BEGIN SELECT RAISE(ABORT,'staging and import blockers must pass governed promotion before approval'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER catalog_staging_validation_gate BEFORE INSERT ON catalog_publication_validations
      WHEN EXISTS (
        SELECT 1 FROM catalog_staging_entries s WHERE s.catalog_version_id=NEW.catalog_version_id
      ) OR EXISTS (
        SELECT 1 FROM catalog_import_blockers b
        WHERE b.catalog_version_id=NEW.catalog_version_id
          AND b.severity IN ('publishBlocker','error')
      ) BEGIN SELECT RAISE(ABORT,'staged entries or import blockers cannot receive publication validation'); END''',
    );
  }

  static Future<void> _createSameVersionGuards(DatabaseExecutor db) async {
    const references = <(String, String, String)>[
      ('catalog_entry_relations', 'from_entry_id', 'catalog_entries'),
      ('catalog_entry_relations', 'to_entry_id', 'catalog_entries'),
      ('templates', 'catalog_entry_id', 'catalog_entries'),
      ('module_versions', 'catalog_entry_id', 'catalog_entries'),
      ('variants', 'template_id', 'templates'),
      ('engine_bindings', 'variant_id', 'variants'),
      ('engine_binding_variants', 'engine_binding_id', 'engine_bindings'),
      ('engine_binding_variants', 'variant_id', 'variants'),
      ('engine_binding_capabilities', 'engine_binding_id', 'engine_bindings'),
      ('engine_binding_schedules', 'engine_binding_id', 'engine_bindings'),
      ('engine_binding_schedules', 'schedule_id', 'schedules'),
      ('engine_binding_options', 'engine_binding_id', 'engine_bindings'),
      (
        'engine_binding_migration_aliases',
        'engine_binding_id',
        'engine_bindings',
      ),
      ('parameter_schemas', 'variant_id', 'variants'),
      ('variant_module_bindings', 'variant_id', 'variants'),
      ('variant_module_bindings', 'module_version_id', 'module_versions'),
      ('finite_programs', 'template_id', 'templates'),
      ('finite_program_phases', 'finite_program_id', 'finite_programs'),
      ('finite_program_segments', 'phase_id', 'finite_program_phases'),
      ('finite_program_segments', 'variant_id', 'variants'),
      ('finite_program_segments', 'schedule_id', 'schedules'),
      ('finite_program_transitions', 'from_phase_id', 'finite_program_phases'),
      ('finite_program_transitions', 'to_phase_id', 'finite_program_phases'),
      ('finite_program_transitions', 'movement_id', 'movements'),
      ('schedules', 'variant_id', 'variants'),
      ('schedule_segments', 'schedule_id', 'schedules'),
      ('schedule_segment_roles', 'segment_id', 'schedule_segments'),
      ('schedule_training_max_evolution', 'schedule_id', 'schedules'),
      ('schedule_training_max_evolution', 'movement_id', 'movements'),
      ('schedule_weeks', 'schedule_id', 'schedules'),
      ('schedule_sessions', 'week_id', 'schedule_weeks'),
      ('session_blocks', 'session_id', 'schedule_sessions'),
      ('session_blocks', 'module_version_id', 'module_versions'),
      ('movements', 'catalog_entry_id', 'catalog_entries'),
      ('movements', 'category_id', 'movement_categories'),
      ('movement_capabilities', 'movement_id', 'movements'),
      ('conditioning_definitions', 'movement_id', 'movements'),
      (
        'conditioning_modalities',
        'conditioning_definition_id',
        'conditioning_definitions',
      ),
      ('movement_equipment', 'movement_id', 'movements'),
      ('movement_equipment', 'equipment_id', 'equipment'),
      ('prescriptions', 'block_id', 'session_blocks'),
      ('prescriptions', 'movement_id', 'movements'),
      ('assistance_plans', 'variant_id', 'variants'),
      ('assistance_slots', 'assistance_plan_id', 'assistance_plans'),
      ('assistance_slots', 'category_id', 'movement_categories'),
      ('assistance_slot_movements', 'assistance_slot_id', 'assistance_slots'),
      ('assistance_slot_movements', 'movement_id', 'movements'),
      ('policies', 'variant_id', 'variants'),
    ];
    for (final (table, column, parent) in references) {
      final nullable = const {
        'to_phase_id',
        'module_version_id',
        'category_id',
        'schedule_id',
        'movement_id',
      }.contains(column);
      final mismatch = nullable ? 'NEW.$column IS NOT NULL AND ' : '';
      await db.execute(
        '''CREATE TRIGGER ${table}_${column}_same_version_insert BEFORE INSERT ON $table
        WHEN $mismatch(SELECT catalog_version_id FROM $parent WHERE id=NEW.$column) != NEW.catalog_version_id
        BEGIN SELECT RAISE(ABORT,'cross-version reference'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_${column}_same_version_update BEFORE UPDATE OF $column ON $table
        WHEN $mismatch(SELECT catalog_version_id FROM $parent WHERE id=NEW.$column) != NEW.catalog_version_id
        BEGIN SELECT RAISE(ABORT,'cross-version reference'); END''',
      );
    }
  }

  static Future<void> _createCatalogIdGuards(DatabaseExecutor db) async {
    const keys = <(String, String)>[
      ('modules', 'stable_key'),
      ('templates', 'stable_key'),
      ('variants', 'stable_key'),
      ('schedules', 'stable_key'),
      ('finite_programs', 'stable_key'),
      ('movement_categories', 'stable_key'),
      ('equipment', 'stable_key'),
      ('movements', 'stable_key'),
      ('assistance_plans', 'stable_key'),
      ('engine_binding_capabilities', 'capability_id'),
      ('engine_binding_options', 'option_id'),
      ('schedule_segment_roles', 'role_id'),
      ('movement_capabilities', 'capability_id'),
    ];
    for (final (table, column) in keys) {
      final invalid =
          '''NEW.$column != lower(NEW.$column) OR length(NEW.$column)=0
        OR NEW.$column GLOB '*[^a-z0-9-]*' OR NEW.$column LIKE '-%'
        OR NEW.$column LIKE '%-' OR NEW.$column LIKE '%--%' ''';
      await db.execute(
        '''CREATE TRIGGER ${table}_${column}_catalog_id_insert BEFORE INSERT ON $table
        WHEN $invalid BEGIN SELECT RAISE(ABORT,'invalid CatalogId'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_${column}_catalog_id_update BEFORE UPDATE OF $column ON $table
        WHEN $invalid BEGIN SELECT RAISE(ABORT,'invalid CatalogId'); END''',
      );
    }
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    if (oldVersion == 1 && newVersion == 2) {
      await _createAdministrationStaging(db);
      return;
    }
    throw StateError(
      'No catalog.db migration from $oldVersion to $newVersion.',
    );
  }

  static const _versionedTables = <String>[
    'catalog_entries',
    'catalog_entry_relations',
    'evidence',
    'module_versions',
    'templates',
    'variants',
    'engine_bindings',
    'engine_binding_variants',
    'engine_binding_capabilities',
    'engine_binding_schedules',
    'engine_binding_options',
    'engine_binding_migration_aliases',
    'parameter_schemas',
    'variant_module_bindings',
    'declarative_rules',
    'finite_programs',
    'finite_program_phases',
    'finite_program_segments',
    'finite_program_transitions',
    'schedules',
    'schedule_segments',
    'schedule_segment_roles',
    'schedule_training_max_evolution',
    'schedule_weeks',
    'schedule_sessions',
    'session_blocks',
    'movement_categories',
    'equipment',
    'movements',
    'movement_capabilities',
    'conditioning_definitions',
    'conditioning_modalities',
    'movement_equipment',
    'prescriptions',
    'assistance_plans',
    'assistance_slots',
    'assistance_slot_movements',
    'policies',
  ];
}
