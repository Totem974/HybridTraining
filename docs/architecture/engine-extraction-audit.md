# G2 — Audit d’extraction du moteur

Portée : checkpoint `codex/cycle-ui-source-parity-v2`, cible
`packages/training_engine`, audit statique des sources sous `lib/`. Les classes
ci-dessous sont classées par destination, pas par qualité fonctionnelle.

## Décision

Le moteur Cycle/Forever peut être extrait sans réécriture des calculs. Le noyau
est Dart pur et ne contient aucun import Flutter, `sqflite` ou `dart:io`. Le
déplacement doit toutefois être atomique : Flutter réimporte immédiatement le
package, afin de ne jamais maintenir deux compilateurs/codecs actifs.

## Inventaire classé

| Classe | Chemins | Action |
|---|---|---|
| `PURE_DART_MOVE` | `features/cycle_generation/domain/*.dart` | Déplacer modèles, calculs, plating, erreurs, `CycleCompilerImpl`, workspace codec. |
| `PURE_DART_MOVE` | `features/cycle_generation/application/catalog_cycle_primitive_codec.dart`, `catalog_plan_resolver.dart` | Déplacer les codecs/résolveurs d’objets déjà chargés. |
| `PURE_DART_MOVE` | `features/forever/domain/*.dart`, `features/forever/application/forever_composer_impl.dart` | Déplacer contrats et `ForeverComposer`; aucune dépendance plateforme. |
| `PURE_DART_MOVE` | `features/training_catalog/domain/*.dart` | Déplacer modèles, index, couverture et codec catalogue. |
| `PURE_DART_MOVE` | `features/training_catalog/data/catalog_plan_data_resolver.dart`, `catalog_source_document_codec.dart` | Déplacer comme codecs de snapshot JSON; renommer hors `data` dans le package. |
| `PURE_DART_MOVE` | `features/gyms/domain/plate_calculator.dart`, `features/training_max/domain/*.dart` | Déplacer plating et calculs TM. |
| `PURE_DART_MOVE` | `features/programs/domain/**/*.dart` | Déplacer les modèles/générateurs encore requis par les contrats et goldens; les isoler comme compatibilité interne. |
| `PURE_DART_MOVE` | `features/training_log/domain/training_snapshot.dart` | Déplacer le snapshot métier requis par Cycle. |
| `ADAPTER_KEEP` | `features/training_catalog/application/catalog_repository.dart` | Garder une interface côté Flutter, ou déplacer une interface de port neutralisée; son import inverse vers Cycle crée un cycle de feature. |
| `ADAPTER_KEEP` | `features/cycle_generation/application/definition_resolver.dart`, `workspace_program_repository.dart` | Adaptateurs/orchestration de repository; le moteur doit recevoir une définition résolue. |
| `ADAPTER_KEEP` | `features/cycle_generation/data/*.dart` | SQLite workspace et schéma; hors SDK. Injecter horloge au repository. |
| `ADAPTER_KEEP` | `features/training_catalog/data/runtime_catalog_builder.dart`, `runtime_catalog_publisher.dart`, `sqlite_training_catalog.dart` | Pipeline/lecture SQLite natifs; convertir leur sortie en snapshot moteur. |
| `ADAPTER_KEEP` | `features/cycle_web/application/cycle_web_application_impl.dart`, `cycle_web_draft_repository.dart` | Orchestration Flutter, persistance et export; remplacer l’accès repository par appels au SDK. |
| `ADAPTER_KEEP` | `features/cycle_web/data/*.dart`, `features/forever/data/*sqlite*.dart`, `forever_json_export.dart` | Persistance/export Flutter; jamais dans le moteur. |
| `ADAPTER_KEEP` | `features/*/data/sqlite_*.dart`, `core/database/**`, `core/storage/**` | Tous les adaptateurs et infrastructures SQLite restent dans l’application oracle. |
| `UI_ONLY` | `app/**`, `main*.dart`, `features/**/presentation/**`, `features/generator_web/**` | Flutter, localisation et composition UI; oracle uniquement. |
| `UI_ONLY` | `features/cycle_web/application/cycle_web_contract.dart`, `cycle_option_condition_evaluator.dart` | État/visibilité de l’éditeur actuel; remplacer par le contrat public `CycleEditorSchema`, sans importer les widgets. |
| `LEGACY_GOLDEN_ONLY` | `features/poc_531/**` | Ancien moteur/adaptateurs : conserver seulement comme oracle de golden pendant la parité. |
| `LEGACY_GOLDEN_ONLY` | `features/programs/domain/original_fsl_program.dart`, `program_generator_factory.dart`, `program_library.dart`, `v2/program_v1_adapter.dart`, `v2/generation/original_fsl_macrocycle_adapter.dart` | Compatibilité historique; ne pas exposer dans l’API SDK et figer par goldens. |
| `DROP_LATER` | `features/poc_531/**` et adaptateurs legacy ci-dessus | Supprimer seulement après parité native/JS et autorisation de retrait de l’oracle. |
| `DROP_LATER` | bootstrap/pages Flutter Web Cycle devenus sans consommateurs | Retrait au cutover autorisé; pas pendant l’extraction. |

## Contaminations constatées

- Flutter : imports dans `app/**`, toutes les présentations Cycle/Forever,
  `generator_web`, et `forever_web_contract.dart`. Aucun dans le noyau proposé.
- SQLite : `core/database/**`, `core/storage/**`, tous les repositories `sqlite_*`,
  les schémas workspace/Forever et le builder/catalogue SQLite. Ces fichiers ne
  doivent pas franchir la frontière SDK.
- `dart:io` : aucun import trouvé sous `lib/`.
- Horloge globale : `sqlite_workspace_program_repository.dart` appelle
  `DateTime.now()` directement. Les autres défauts d’horloge sont dans les
  adaptateurs et déjà injectables; les bootstraps/pages peuvent rester UI.
- Base directe : `definition_resolver.dart` passe par des ports, mais
  `CycleWebApplicationImpl` résout le catalogue et écrit draft/snapshot. Le
  bridge ne doit reprendre aucune de ces responsabilités : `initialize` reçoit
  le bundle, puis le moteur travaille sur snapshots résolus.
- Localisation domaine : aucune dépendance à `AppStrings`/`intl` dans le noyau.
  En revanche `CycleGenerationWarning.toJson()` expose un champ `message` et
  plusieurs exceptions contiennent de l’anglais. Remplacer à la frontière
  publique par `code`, `path`, `messageKey`, `details`, `severity`; garder les
  textes seulement pour debug/tests internes.

## Cycles et couplages à casser

1. `training_catalog/application/catalog_repository.dart` importe les contrats
   Cycle, tandis que `cycle_generation/application/definition_resolver.dart`
   importe ce repository : cycle logique catalogue ↔ génération. Créer dans le
   SDK un snapshot catalogue autonome et faire résoudre SQLite avant l’appel.
2. `cycle_web_contract.dart` importe `training_snapshot.dart`; l’état d’éditeur
   et le résultat généré sont ainsi confondus. Les séparer en `CycleRequest`,
   `CycleResponse` et `SnapshotEnvelope` versionnés.
3. `forever_web_application_impl.dart` importe Cycle Web, repositories SQLite et
   même un contrat de présentation. Ne déplacer que `ForeverComposer` et ses
   contrats; reconstruire l’orchestration via le bridge ultérieurement.
4. `workspace_database_schema.dart` appelle le schéma Forever : dépendance de
   migration DB, pas dépendance métier. Elle reste côté Flutter.

## Séquence sûre d’extraction

1. Geler les sorties des 23 variantes et Forever avec JSON canonique.
2. Définir les exports publics du package et les snapshots catalogue résolus.
3. Déplacer une seule fois les groupes `PURE_DART_MOVE`, puis corriger tous les
   imports Flutter vers `package:training_engine`; aucun shim de calcul local.
4. Garder les éléments `LEGACY_GOLDEN_ONLY` hors exports et vérifier que le
   nouveau compilateur seul produit les goldens.
5. Ajouter les contrats JSON stricts et seulement ensuite le bridge JS.

## Gate G2

- Recherche SDK négative : `package:flutter`, `sqflite`, `dart:io`, DOM et
  imports vers `lib/features/**/presentation`.
- Graphe package acyclique : catalogue snapshot → compiler/composer → réponse.
- Horloge/date/cycle id fournis dans la requête; aucun `DateTime.now()` moteur.
- Flutter analyse/tests/build inchangés après bascule de ses imports.
- Goldens natifs identiques avant/après extraction; suppression différée.
