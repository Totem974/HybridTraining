# Passation IA Pro — Générateur de cycles

Date : 21 juillet 2026
Branche : `codex/catalog-complete-cycle-web-poc-v1`

## Décision produit

La priorité exclusive est le générateur de cycles piloté par catalogue.

Forever ne doit pas être développé maintenant. Forever sera plus tard un générateur de macrocycles qui composera des cycles en appelant le même `CycleCompiler`. Son inventaire historique peut rester consultable, mais aucune entrée Forever ne doit devenir un template Cycle pendant ce chantier.

## Architecture retenue

```text
catalog_src déclaratif
→ lint et build déterministes
→ catalog.db publié
→ résolution d'une définition
→ CycleCompiler Dart pur
→ GeneratedCycle
→ snapshot autonome dans training.db
```

Responsabilités de stockage :

- `catalog.db` : règles et définitions publiées ;
- `workspace.db` : profil, max, matériel, préférences et brouillons ;
- `training.db` : cycles générés, séances, séries prévues et résultats.

Le compilateur ne lit ni SQLite ni l'horloge globale, ne dépend pas de Flutter et ne branche jamais sur un identifiant de template.

## État livré

- Contrats catalogue, compilateur et Web gelés.
- Schéma SQLite catalogue versionné et migrations ajoutées.
- Requêtes dynamiques pour index et schémas d'éditeur.
- Primitives génériques : plans hebdomadaires, phases répétées, charges relatives, exécution de séries et décisions runtime.
- Codec strict des documents catalogue et résolution générique vers `CatalogPlan`.
- Builder déterministe fondé sur l'ensemble de `catalog_src`, sans copie de l'ancien asset BBB.
- Interface `CycleWebPage`, route `/cycle`, champs dynamiques, brouillons SQLite et service applicatif présents.
- Inventaire déclaré : 354/354 entrées classifiées.
- Catalogue déclaré : 16 templates, 19 variantes, 51 composants, 9 schémas d'options, 8 schedules, 6 mouvements, 30 exercices, 8 plans d'assistance et 11 définitions de conditioning.
- Forever : 182 entrées historiques et zéro template Cycle actif.

Familles actuellement normalisées ou partiellement normalisées : Standard, Powerlifting, BBB, Triumvirate, Periodization Bible, Bodyweight, Simplest Strength, Beginners, Full Body phases 1–3, Pyramid, First Set Last et 5's Progression.

## État réel — ne pas considérer le POC comme terminé

La page Cycle n'est pas encore lançable depuis l'application principale.

1. `HybridTrainingApp` démarre toujours l'ancien `Poc531GeneratorPage` et utilise encore les routes `poc_531`.
2. `/cycle` n'est pas raccordé à la composition root ni aux trois bases runtime.
3. Le catalogue exhaustif n'est pas encore produit et chargé comme véritable `catalog.db` Web.
4. Le support SQLite Web et ses binaires WASM/worker ne sont pas encore raccordés.
5. Aucun scénario Chrome complet génération → sauvegarde → relecture n'est validé.
6. Quatre suites ciblées échouaient lors du dernier audit :
   - typage trop large dans `test/catalog/beyond/beyond_inventory_test.dart` ;
   - switch SQLite non exhaustif pour `RelativeSetLoad` dans `sqlite_training_catalog.dart`, bloquant notamment les tests Standard/BBB et migration catalogue.
7. Le compteur `compileFailures == 0` est actuellement insuffisant : il vérifie la présence d'exemples, mais ne compile pas encore réellement chaque variante via SQLite et le même compilateur.

## Prochain plan recommandé

### Gate 1 — restaurer un socle réellement vert

- Corriger les erreurs de compilation Beyond et `RelativeSetLoad`.
- Exécuter les tests catalogue, compilateur, SQLite et Web ciblés.
- Faire évoluer la couverture pour résoudre et compiler réellement chaque variante.

### Gate 2 — catalogue runtime

- Transformer le build déclaratif en base SQLite publiée, déterministe et immuable.
- Charger cette base au runtime au lieu des deux anciens assets Standard/BBB.
- Prouver Classic, Beyond et Powerlifting depuis SQLite.

### Gate 3 — composition Web

- Raccorder `CycleWebRoute` dans `HybridTrainingApp`.
- Ouvrir séparément `catalog.db`, `workspace.db` et `training.db`.
- Installer/configurer l'adaptateur SQLite Web et les fichiers WASM nécessaires.
- Préserver la navigation Forever existante sans développer son générateur.

### Gate 4 — validation utilisateur

- Lancer le POC dans Chrome.
- Tester sélection template/variante, max/TM, options, schedule, génération, plaques, sauvegarde et relecture.
- Exécuter enfin : formatage, analyse, tests complets, contrôle du diff et build Web release.

## Organisation actuelle du dépôt

- `assets/` : anciens seeds Standard/BBB encore utilisés ; à conserver jusqu'au basculement runtime.
- `catalog_src/` : source déclarative centrale ; à conserver.
- `integration_test/` : scénarios bout en bout ; à conserver.
- `lib/` : application et domaines ; indispensable.
- `test/` : tests unitaires, SQLite et widgets ; indispensable.
- `test_driver/` : ancien point d'entrée d'intégration ; à retirer seulement après migration Chrome confirmée.
- `tool/` : lint, builder et couverture catalogue ; indispensable.
- `web/` : shell Flutter Web ; indispensable.
- `docs/sources-local/` : PDF et oracles locaux ignorés par Git.
- `.cleanup-backup/` : sauvegarde locale récupérable des archives retirées, ignorée par Git.

Les anciens rapports IA et les caches Dart accidentellement versionnés ont été retirés. Les documents actifs restants décrivent les contrats courants.

## Contraintes à respecter

- Ne pas commencer Forever avant validation complète du générateur Cycle.
- Ne jamais inventer une prescription manquante.
- Ne pas créer de compilateur spécialisé par template.
- Ne pas mettre de règle d'entraînement dans les widgets.
- Préserver les trois bases et l'absence de clés étrangères inter-base.
- Ne pas annoncer une suite ou un navigateur passant sans exécution réelle.
- Aucun push forcé et aucune fusion globale d'une branche donneuse.
