# AGENTS.md — HybridTraining

## 1. Objectif produit

HybridTraining est une application locale-first de programmation et de suivi d'entraînement.

La chaîne Cycle, désormais fondation stable, est :

```text
catalog.db publié
+ choix utilisateur
+ 1RM / rep-max / Training Max
+ ratio TM
+ schedule
+ matériel
+ assistance / conditioning
= GeneratedCycle
```

La chaîne Forever à construire est :

```text
ForeverDefinition publiée
+ choix utilisateur
+ Training Max initiaux
= liste ordonnée de CycleRequest
→ même CycleCompiler
→ GeneratedMacrocycle
```

L'interface ne contient aucune règle d'entraînement.

## 2. État de référence

Le POC Cycle catalogue-first est la fondation officielle.

Il comprend :

- source déclarative `catalog_src` ;
- `catalog.db` runtime publié ;
- `CatalogResolver` ;
- `CycleCompiler` pur ;
- `/cycle` ;
- brouillons dans `workspace.db` ;
- snapshots et résultats dans `training.db` ;
- compilation exhaustive des variantes Cycle déclarées.

Ne pas reconstruire cette chaîne.

Une modification du Cycle est autorisée uniquement pour :

- corriger une régression démontrée ;
- ajouter une primitive générique indispensable à Forever ;
- renforcer une interface publique sans branchement par template.

## 3. Priorité active

```text
1. FIGER ET SAUVEGARDER LE POC CYCLE
2. CONSTRUIRE LE POC FOREVER GÉNÉRIQUE
3. RACCORDER /forever
4. VALIDER UN MACROCYCLE DE BOUT EN BOUT
```

Les travaux de statistiques, synchronisation distante, comptes, paiement, Android produit et refonte visuelle restent hors périmètre.

## 4. Trois bases

### `catalog.db`

Contient :

- définitions Cycle publiées ;
- composants partagés ;
- mouvements et exercices ;
- schedules ;
- assistance et conditioning ;
- définitions Forever ;
- rôles Leader/Anchor ;
- transitions ;
- protocoles de deload/test ;
- règles d'évolution du Training Max.

Une version publiée est immuable.

### `workspace.db`

Contient :

- profil ;
- max et ratios ;
- matériel ;
- préférences ;
- brouillon Cycle ;
- brouillon Forever ;
- configurations enregistrées ;
- définitions personnalisées.

### `training.db`

Contient :

- snapshots Cycle ;
- macrocycles ;
- ordre des cycles ;
- snapshots enfants ;
- états ;
- résultats ;
- événements ;
- données nécessaires aux statistiques futures.

Aucune clé étrangère inter-base.

## 5. Architecture du domaine

```text
presentation → application → domain
data/infrastructure → ports application/domain
```

Les domaines Cycle et Forever sont en Dart pur, sans Flutter, SQLite ou legacy.

Le nouveau code métier utilise des noms génériques et ne doit pas être ajouté sous `poc_531`.

## 6. CycleCompiler gelé

Contrat :

```text
ResolvedCycleDefinition
+ CycleRequest
= GeneratedCycle
```

Interdictions :

- calcul de séries dans Forever ;
- compilateur spécialisé Leader ou Anchor ;
- `switch(templateId)` ;
- `if (templateId == ...)` ;
- appel au moteur legacy ;
- requête SQLite dans le compilateur ;
- dépendance Flutter dans le domaine.

Forever doit appeler le même `CycleCompiler` pour chaque cycle.

## 7. Modèle Forever

Une définition Forever est déclarative et versionnée.

Elle décrit au minimum :

- identité et révision ;
- source et références ;
- phases ordonnées ;
- rôles `leader`, `anchor`, `transition`, `deload`, `test` ou `custom` ;
- nombre de répétitions d'une phase ;
- définition Cycle ou protocole référencé ;
- paramètres par défaut ;
- paramètres modifiables ;
- contraintes de compatibilité ;
- règles de Training Max ;
- règles de passage au nœud suivant ;
- options d'assistance et conditioning ;
- schéma d'éditeur Web.

Une définition ne contient pas de séries copiées. Elle référence des définitions Cycle ou des protocoles compilables par le moteur Cycle.

## 8. ForeverComposer

Contrat conceptuel :

```text
ResolvedForeverDefinition
+ ForeverRequest
+ InitialTrainingMaxes
= GeneratedMacrocycle
```

Le compositeur :

- est pur et déterministe ;
- ne lit pas SQLite ;
- reçoit explicitement la date de départ ;
- résout une séquence finie ;
- produit un `CycleRequest` par cycle ou protocole ;
- appelle `CycleCompiler` ;
- transporte les Training Max entre les cycles ;
- distingue valeurs projetées et confirmées ;
- conserve l'identité et le snapshot de chaque cycle ;
- ne modifie jamais un cycle terminé ;
- produit un macrocycle à la fois.

## 9. Training Max dans Forever

Les règles doivent être explicites et versionnées :

- conserver ;
- ajouter une valeur ;
- multiplier ;
- tester puis confirmer ;
- valeur projetée ;
- valeur confirmée.

Une évolution s'applique à partir d'un nœud précis.

Une valeur projetée ne doit pas écraser silencieusement un résultat confirmé.

## 10. Persistance Forever

`training.db` doit permettre :

```text
macrocycle
├── définition et version
├── snapshot global
├── cycles enfants ordonnés
├── Training Max projetés
├── Training Max confirmés
├── transitions
└── état
```

Chaque cycle enfant conserve son snapshot autonome.

États minimum :

```text
draft
scheduled
active
completed
cancelled
```

Un cycle enfant terminé est immuable.

## 11. POC Web Forever

Créer ou raccorder `/forever`.

Réutiliser sélectivement l'interface Forever existante :

- timeline ;
- cartes ;
- responsive ;
- accessibilité ;
- traductions ;
- contrôles de choix.

Supprimer ou éviter :

- logique par semaine codée en dur ;
- séries calculées dans les widgets ;
- anciens Maps ou codecs concurrents ;
- branchement sur une recette ;
- moteur Forever historique dans le chemin de production.

Le parcours doit permettre :

- choisir une définition Forever publiée ;
- voir sa structure Leader/Anchor/transition ;
- choisir les variantes Cycle autorisées ;
- saisir ou reprendre les Training Max ;
- configurer les options exposées ;
- prévisualiser la timeline ;
- générer le macrocycle ;
- sauvegarder ;
- recharger ;
- ouvrir chaque cycle dans le format Cycle existant.

L'onglet `/cycle` ne doit pas régresser.

## 12. Première preuve fonctionnelle

Commencer par une seule recette Forever entièrement vérifiée dans les sources et audits existants.

Candidat attendu : une structure finie de type :

```text
Leader
→ Leader
→ 7th Week Deload
→ Anchor
→ TM Test
```

Ne pas supposer ce candidat correct : vérifier la définition exacte avant implémentation.

Une fois le compositeur prouvé, ajouter les autres définitions Forever entièrement sourcées sans modifier le moteur.

Les entrées documentaires restent dans l'inventaire mais ne sont pas visibles comme programmes désactivés.

## 13. Validation du POC Cycle avant Forever

Avant la nouvelle branche Forever :

- vérifier les commits locaux ;
- exécuter les tests ciblés Cycle ;
- confirmer les compteurs de couverture ;
- effectuer un parcours Chrome manuel documenté si l'automatisation complète reste bloquée ;
- ne pas passer plus d'un lot borné à contourner WebDriver.

Une limitation du pilote navigateur n'autorise pas à déclarer un E2E automatisé passant, mais ne doit pas bloquer indéfiniment Forever si le parcours manuel et les tests de couches sont verts.

## 14. Agents parallèles

Utiliser tous les slots disponibles avec chemins exclusifs.

Répartition recommandée :

1. audit et normalisation des définitions Forever ;
2. domaine `ForeverRequest` / `GeneratedMacrocycle` ;
3. `ForeverComposer` et TM ;
4. persistance `training.db` / `workspace.db` ;
5. `/forever` et view-model ;
6. tests goldens et intégration ;
7. validation navigateur et accessibilité ;
8. revue architecturale read-only.

Le lead possède :

- contrats publics ;
- migrations partagées ;
- composition root ;
- intégration ;
- commits.

## 15. Efficacité

- Ne pas refaire l'audit Cycle.
- Ne pas renormaliser les 354 entrées Cycle.
- Ne pas reconstruire `/cycle`.
- Ne pas créer de nouveau moteur par recette.
- Ne pas développer toutes les entrées Forever avant la première preuve.
- Ne pas écrire de longs ADR.
- Ne pas ajouter de sécurité spéculative.
- Tests ciblés pendant les lots ; suite complète aux gates.
- Ne pas boucler indéfiniment sur WebDriver.

## 16. Validation

À chaque gate :

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

Pour les changements Web :

```text
flutter build web --release
```

Validation finale :

- Cycle inchangé et vert ;
- définition Forever chargée depuis `catalog.db` ;
- chaque cycle du macrocycle généré par `CycleCompiler` ;
- TM transportés correctement ;
- snapshots sauvegardés et relus ;
- `/forever` fonctionnel ;
- parcours navigateur réel documenté ;
- worktree propre.

## 17. Git

- Préserver les changements utilisateur.
- Ne jamais utiliser `git reset --hard`.
- Ne jamais forcer un push.
- Créer une branche Forever depuis le HEAD Cycle validé.
- Petits commits cohérents.
- Diff et tests avant commit.
- Aucun push sans autorisation explicite.
