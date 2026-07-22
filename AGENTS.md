# AGENTS.md — HybridTraining

## 1. Fondation stable

Le catalogue, le générateur Cycle et le premier compositeur Forever sont des fondations existantes.

Chaîne Cycle :

```text
catalog.db
+ choix utilisateur
→ CatalogResolver
→ CycleCompiler pur
→ GeneratedCycle
```

Chaîne Forever :

```text
ForeverDefinition
+ configurations de nœuds
→ ForeverComposer
→ CycleRequest[]
→ même CycleCompiler
→ GeneratedMacrocycle
```

Ne pas reconstruire le catalogue ou le moteur Cycle. Toute évolution doit rester générique et rétrocompatible.

## 2. Périmètre Web actuel

Le produit Web comporte exactement deux pages principales :

```text
/cycle
/forever
```

Une bascule commune permet de passer de l’une à l’autre.

Hors périmètre Web actuel :

- séance du jour ;
- suivi d’exécution ;
- recommandations automatiques ;
- statistiques ;
- génération automatique du prochain cycle ;
- génération automatique du prochain macrocycle ;
- continuité pilotée par les résultats ;
- application Android produit.

Le Web génère un cycle ou un macrocycle autonome. Lors d’une prochaine utilisation, l’utilisateur ressaisit ou recharge ses max et crée une nouvelle génération indépendante.

## 3. Priorité active

```text
1. REFAIRE L’INTERFACE WEB CYCLE
2. REFAIRE LE CONFIGURATEUR WEB FOREVER
3. ÉTENDRE FOREVER AUX PRESETS ET ARCHITECTURES PERSONNALISÉES
4. VALIDER LES DEUX PAGES
```

La lisibilité et la conformité visuelle à la référence fournie sont des critères bloquants.

## 4. Référence visuelle

Utiliser les captures et le miroir HTML/CSS fournis comme référence de mise en page et d’interaction.

Caractéristiques cibles :

- fond `#181818` ;
- contenu centré d’environ 900 px ;
- cartes `#323232` ;
- rayon d’environ 18 px ;
- texte clair ;
- accent bleu proche de `#2C9EFF` ;
- espacements de 24 px ;
- deux colonnes sur desktop ;
- une colonne sous environ 770 px ;
- sections larges et repliables ;
- contrôles compacts ;
- programme généré lisible par semaines et séances.

Ne pas copier :

- code React/minifié ;
- marque ;
- logo ;
- actifs ;
- police archivée.

Utiliser les composants, icônes, traductions et polices déjà autorisés dans le projet.

## 5. Structure commune des deux pages

```text
HEADER
titre + bascule [Cycle | Forever]

FORMULAIRE
sections en cartes

OUTPUT
résumé + actions

PROGRAM
résultat généré
```

Conserver un langage visuel identique entre `/cycle` et `/forever`.

## 6. Page `/cycle`

Disposition desktop :

```text
WEIGHT                    TEMPLATE
ADDITIONAL OPTIONS
PLATING & BARBELL
SCHEDULING                OUTPUT
PROGRAM
```

La page réutilise le moteur et les contrats existants :

```text
CycleCatalogIndex
CycleEditorSchema
CycleEditorState
CycleEditorIntent
CycleRequest
GeneratedCycleView
```

Aucune règle métier dans les widgets.

Toutes les options visibles proviennent du catalogue.

## 7. Page `/forever`

Disposition desktop :

```text
WEIGHT                    MACROCYCLE
GLOBAL OPTIONS
PLATING & BARBELL
CYCLES
TIMELINE                  OUTPUT
PROGRAM
```

### Choix du macrocycle

Deux modes :

```text
Programme prédéfini
Architecture personnalisée
```

Un preset publié charge une architecture et des contraintes sourcées.

Une architecture personnalisée est `userDefined`.

### Nœuds

Nœuds minimum :

```text
leader
anchor
transition
deload
test
custom
```

Affichage compact d’un cycle :

```text
C1 — Leader
Template [select]
Variante [select]
[Configurer]
Résumé des options
```

### Configuration détaillée

Le bouton `Configurer` réutilise l’éditeur Cycle existant :

- modal ou panneau sur desktop ;
- plein écran sur mobile.

Ne jamais créer un second moteur ou recopier les règles Cycle.

## 8. Macrocycle autonome

Le Web génère un macrocycle fini et autonome.

Il accepte :

- max saisis ou chargés ;
- architecture ;
- configurations des cycles ;
- matériel ;
- date ;
- options.

Il produit :

- timeline ;
- cycles enfants ;
- TM projetés à l’intérieur du macrocycle ;
- charges et plaques ;
- snapshot ;
- export/sauvegarde.

Ne pas implémenter dans cette phase :

```text
previousMacrocycleId
nextMacrocycleId
Générer le macrocycle suivant
recommandation depuis les résultats
mise à jour automatique des max
```

Ces fonctions appartiendront à l’application d’entraînement future.

## 9. Preset et architecture personnalisée

### Preset

- sélectionner un preset publié ;
- afficher sa structure ;
- verrouiller les éléments canoniques ;
- permettre uniquement les modifications déclarées.

### Architecture personnalisée

Permettre :

- ajouter un Leader ;
- ajouter un Anchor ;
- ajouter un protocole ;
- supprimer un nœud non obligatoire ;
- réordonner ;
- dupliquer un cycle ;
- copier une configuration ;
- enregistrer le brouillon.

Contraintes minimum :

- séquence non vide ;
- cycle configuré ;
- protocole non orphelin ;
- rôle compatible ;
- macrocycle fini.

## 10. Configuration par nœud

Chaque nœud Cycle référence une configuration complète :

```text
template
variant
parameters
warm-up
Joker
deload
supplemental
assistance
conditioning
schedule
ordre des séances
ratios
matériel
```

Résolution :

```text
defaults globaux
→ defaults du preset
→ defaults du rôle
→ configuration du nœud
```

Aucune valeur incompatible n’est supprimée silencieusement.

## 11. ForeverComposer

Le compositeur :

- reste pur et déterministe ;
- ne lit pas SQLite ;
- ne dépend pas de Flutter ou du legacy ;
- ne calcule aucune série ;
- produit un macrocycle fini ;
- appelle `CycleCompiler` pour chaque cycle ;
- applique les règles TM uniquement à l’intérieur du macrocycle ;
- préserve les snapshots enfants.

Interdictions :

```text
LeaderCompiler
AnchorCompiler
switch(templateId)
if (templateId == ...)
calcul de séries dans Forever
règles métier dans les widgets
```

## 12. Persistance Web

### `workspace.db`

Conserve :

- brouillon Cycle ;
- brouillon Forever ;
- mode preset/custom ;
- architecture ;
- réglages globaux ;
- configurations des nœuds ;
- max ;
- matériel ;
- version du payload.

### `training.db`

Conserve le cycle ou macrocycle généré et ses snapshots.

Aucune logique de recommandation du prochain programme.

## 13. Export

Les deux pages doivent pouvoir au minimum :

- sauvegarder ;
- recharger ;
- exporter la configuration ou le résultat dans le format prévu par le projet.

L’import dans l’application d’entraînement future ne doit pas imposer aujourd’hui son workflow Android.

## 14. Provenance

- Preset canonique : référence au livre.
- Architecture libre : `userDefined`.
- Observation de référence : `referenceAppObserved`.
- Ne jamais inventer une architecture canonique ou une compatibilité.

## 15. Agents parallèles

Utiliser tous les slots disponibles avec chemins exclusifs :

1. audit visuel et design system Web ;
2. refonte `/cycle` ;
3. modèle Forever preset/custom ;
4. éditeur Cycle embarqué ;
5. refonte `/forever` ;
6. persistance/export ;
7. responsive, FR/EN, accessibilité ;
8. tests et revue architecturale.

Le lead possède les contrats publics, migrations partagées, composition root et intégration.

## 16. Efficacité

- Ne pas refaire le catalogue.
- Ne pas refaire le moteur Cycle.
- Ne pas préparer l’application Android.
- Ne pas implémenter la suite automatique.
- Ne pas boucler sur WebDriver.
- Ne pas écrire de longs ADR.
- Tests ciblés pendant les lots ; suite complète aux gates.

## 17. Validation

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
flutter build web --release
```

Validation visuelle réelle :

- `/cycle` desktop et mobile ;
- `/forever` desktop et mobile ;
- FR et EN ;
- clavier et accessibilité ;
- génération ;
- sauvegarde/rechargement ;
- export ;
- aucune erreur console.

## 18. Git

- Préserver les changements utilisateur.
- Jamais de `git reset --hard`.
- Jamais de push forcé.
- Petits commits cohérents.
- Aucun push sans autorisation explicite.
