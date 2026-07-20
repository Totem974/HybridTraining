# Audit du mode Forever

Date : 2026-07-20  
Branche de référence : `GitHub/poc/531-core-web-onboarding`  
Branche de travail : `refactor/forever-mode-composer`

## Périmètre et décision

Cet audit précède toute modification produit. Trois audits parallèles, strictement
en lecture seule, ont couvert le dépôt, le domaine Forever et l'interface. La
mission lève le gel temporaire de l'UI défini dans `AGENTS.md` uniquement pour la
surface isolée `/poc/531`; le Core Validation Shell et les autres routes restent
hors périmètre.

Le vertical slice doit conserver le moteur Classic actuel et introduire une
frontière typée entre `cycle` et `forever`. Le domaine Dart pur reste l'unique
autorité des séquences, protocoles, compatibilités et Training Max.

## Architecture actuelle

Le dépôt est un mono-package Flutter feature-first. Le flux Core v5 documenté est
`ProgramLibrary` → `CanonicalPlanGenerator` → `VersionedTrainingPlan`. Le POC
ajoute une façade Dart pure sous `lib/features/poc_531/domain`, un adaptateur de
présentation et une page Web sous `presentation/generator`.

La page `poc_531_generator_page.dart` concentre près de 1 800 lignes. Son état
repose sur `_mode` (`classic` ou `forever`) et une map de configuration non typée.
`GeneratorOptions` et `ForeverTemplateChoice` appartiennent aujourd'hui à la
couche présentation. Cette structure ne protège ni les invariants ni les
frontières de mode.

Le catalogue indexe 354 entrées : 182 Forever, quatre presets exécutables au
total, dont `FV-141` (Beginner Prep School) et `FV-236` (Forever Original + FSL).
Les 350 autres entrées sont documentaires ou `NEEDS_REVIEW` et doivent rester
non exécutables.

## Flux Cycle actuel

Le flux Classic sélectionne un template et une variante, collecte les lifts,
l'équipement et les options, puis délègue à l'adaptateur et aux calculateurs Dart.
Original, Beyond et l'extension Powerlifting sont déjà couverts. Ce flux doit
rester une surface de compatibilité : il sera enveloppé par une
`CyclePlanningConfiguration`, sans réécriture de ses prescriptions.

Risques observés :

- les deep links Classic ne transmettent pas le programme demandé et retombent
  silencieusement sur le template par défaut ;
- les scénarios d'intégration utilisent encore `programId` là où l'adaptateur
  consomme `templateId` ;
- la restauration ne relit qu'une partie des options sérialisées ;
- Powerlifting doit rester une extension et ne jamais devenir une génération.

## Flux Forever actuel

Le générateur propose un template Forever figé. `forever_calculator.dart` décrit
la séquence `FV-236`, puis délègue à `core.generateProgram`. La page reconstruit
une représentation sommaire de cette séquence. Elle ne compose pas encore des
nœuds typés, ne filtre pas les Anchors par pairing explicite et ne distingue pas
un programme autonome d'un macrocycle.

Beginner Prep School est déjà exécutable avec une structure propre de trois
jours. Il ne doit pas passer par Leader/Anchor. Forever Original + FSL est déjà
exécutable sous forme historique 2 Leaders, 7th Week Deload, Anchor, TM Test.

## Moteurs concurrents

Quatre représentations se chevauchent :

1. `CanonicalPlanGenerator._forever` compose en dur onze semaines et reconnaît
   certains événements par les semaines 3, 6, 7, 8, 10 et 11 ;
2. `ForeverMacrocycleGenerator` interprète des snapshots génériques, mais
   renumérote les semaines par cycle et propose une progression après chaque
   cycle ;
3. `OriginalFslMacrocycleAdapter` reconstruit les prescriptions d'un seul Leader ;
4. `forever_calculator.dart` recopie la séquence et les métadonnées utiles à l'UI.

La cible est un seul compilateur Forever. Une recette versionnée et ses sélections
alimentent une politique de séquence, puis le compilateur produit le plan
canonique. Les anciens points d'entrée peuvent devenir des adaptateurs, mais ne
doivent plus décider de la structure.

## Données déjà disponibles

- modèles versionnés de plans, blocs, cycles, semaines, séances, prescriptions,
  événements, transitions et provenance ;
- rôles Leader et Anchor, protocoles Deload, TM Test et PR Test dans Core v5 ;
- sources revues pour Forever Original + FSL et Beginner Prep School ;
- `ProgramLibraryEntry.isExecutable`, plus strict que le modèle POC actuel ;
- goldens stables des quatre plans de référence, dont
  `forever-original-fsl-2l1a.golden.json` ;
- projection et confirmation de TM, mais encore indexées par semaine dans le POC ;
- catalogue exhaustif et raisons explicites de non-exécutabilité.

## Dette technique

- configuration partagée entre schémas v1 et v2 sans codec ni migration unique ;
- restauration partielle et bouton « Share configuration » copiant le plan ;
- état de mode et identifiants sous forme de chaînes non validées ;
- logique Forever et fallback d'exécutabilité dans la présentation ;
- sources divergentes entre bibliothèque, catalogue généré et calculateur ;
- date fixe et jours consécutifs imposés par l'adaptateur Forever ;
- breakpoints responsive presque inopérants, chaînes non localisées et absence
  d'alternative clavier au glisser-déposer ;
- route onboarding documentée mais retirée du runtime ;
- tests E2E montant directement la page au lieu de vérifier routes et URL.

## Risques

- régression Classic lors de l'extraction du profil commun ;
- dérive du golden historique si deux compilateurs restent décisionnaires ;
- activation accidentelle d'une entrée documentaire via les fallbacks UI ;
- confirmation implicite de TM futurs ;
- payload v2 incomplet ou inconnu accepté silencieusement ;
- combinaison Leader/Anchor inventée faute de pairing revu ;
- divergence calendrier/programming week lors de la migration du preset.

Chaque risque sera couvert par un test préalable ou un invariant bloquant. La
première couverture n'activera que le pairing Original + FSL déjà revu. Un C2
différent restera désactivé tant qu'aucune autre règle explicite n'est disponible.

## Plan de migration

1. Capturer et conserver le golden historique Forever avant la bascule.
2. Introduire `PlanningMode`, `CommonTrainingProfile` et deux configurations
   distinctes, plus un état applicatif avec `cycleDraft` et `foreverDraft`.
3. Définir le schéma de configuration v3 et un codec déterministe avec migration
   v2 → v3 et aliases des anciens IDs.
4. Définir les révisions de templates/protocoles, la recette `forever-2l1a`, les
   nœuds typés et la seule règle de pairing revue disponible.
5. Faire compiler `FV-236` par la nouvelle séquence tout en conservant le résultat
   fonctionnel historique. Les décisions TM seront liées aux `nodeId` et aux
   frontières, jamais à un numéro de semaine.
6. Garder Beginner Prep School sur le chemin autonome.
7. Extraire des composants Cycle et Forever partageant uniquement le profil
   commun; afficher un contrôle segmenté accessible en haut et une timeline.
8. Restaurer mode et payload v3 depuis l'URL, puis aligner les deep links et le
   préremplissage applicatif sans dupliquer les recommandations.
9. Compléter tests unitaires, widget, route, golden, E2E, responsive et
   accessibilité, puis documenter la couverture réelle.

## Critère d'autorité

Une entrée n'est sélectionnable que si la bibliothèque canonique la déclare
exécutable, avec rôle, fréquence, TM, prescriptions, transition et provenance
revus. Une compatibilité n'existe que par une `PairingRule` explicite et sourcée.
Les widgets affichent les choix et problèmes structurés ; ils ne calculent aucune
séquence ni prescription.
