# Audit moteur/résolution — Full Body et options

Date : 2026-07-22. Portée en lecture seule : `catalog_src`,
`packages/training_engine`, bridge local et assemblage de la requête Web.

## Résumé exécutif

- Full Body phases 1–3 est bien défini comme programme multi-mouvement sur trois
  séances, résolu en sessions `monday/wednesday/friday`, puis compilé sans règle
  de template dans `CycleCompilerImpl`.
- Deload est la seule option des trois qui a aujourd’hui un effet métier : le
  front traduit `options.include_deload`, le bridge remplit
  `CycleRequest.includeDeload`, et le compilateur filtre les blocs de rôle
  `deload`.
- Warm-up est exposé par certains option schemas mais sa valeur est perdue dans
  `options`; aucun filtre générique ne relie l’option aux composants warm-up.
- Joker n’existe pas comme option exécutable Cycle. Le catalogue contient des
  références documentaires et le domaine connaît `jokerEligible`, mais aucun
  composant source ne produit ce gate et aucune requête ne l’active.
- Les capacités nécessaires sont majoritairement présentes (catalogue strict,
  ciblage session/mouvement, conditions d’éditeur, options génériques,
  runtime gates), mais il manque un contrat générique d’activation des blocs.

## Trace Full Body

### Catalogue source

`catalog_src/classic/extended/templates.json` publie :

| Template | Variante | Phase | Semaines source | Répétition | Schedule |
|---|---|---:|---:|---:|---|
| `classic_full_body_phase_1` | `phase_1` | 1 | 1–4 | 2 | `classic_extended_three_day_full_body` |
| `classic_full_body_phase_2` | `phase_2` | 2 | 1–4 | 2 | idem |
| `classic_full_body_phase_3` | `phase_3` | 3 | 1–4 | 2 | idem |

La phase 4 est présente dans l’inventaire/règles et dans des composants de
deload, mais aucun quatrième template exécutable n’est publié dans le fichier
extended. L’option schema Full Body ne contient que `training_max_ratio`
per-movement, fixé à 9000; aucune option Warm-up/Joker/Deload n’y est attachée.

Le schedule `classic_extended_three_day_full_body` contient des identités de
séance (`monday`, `wednesday`, `friday`) distinctes des mouvements. Chaque
séance contient plusieurs mouvements, y compris assistance. Les composants
portent correctement `compatibilities.sessionIds` et `movementIds`; les trois
main works ciblent respectivement lundi/squat, mercredi/bench et
vendredi/press+deadlift. Les composants de semaine 4 ont le rôle `deload`.

### Résolution

1. `CatalogSourceDocumentCodec` décode templates, schedules, composants et
   prescriptions. Son codec de `BlockDefinition` n’accepte que `id`, `role`,
   `sets`, `movementId`; il n’existe pas de condition d’activation.
2. `CatalogPlanDataResolver.resolve` vérifie le schedule autorisé, conserve les
   IDs de séances et copie les cibles depuis `compatibilities`. Une relation
   `sameAsMain` est déjà générique et étend un composant aux mouvements du
   schedule.
3. `CatalogPlanResolver.resolve` étend les phases (4 semaines × 2), crée une
   `SessionDefinition` par séance du schedule et applique chaque composant aux
   intersections session/mouvement. La sortie Full Body attendue est donc huit
   semaines, trois séances par semaine, avec plusieurs blocs par séance.
4. `ResolvedCycleDefinition.sessionMovementIds` contient en réalité les IDs de
   séance (`monday/wednesday/friday`). Le nom du champ est trompeur mais le
   compilateur l’utilise comme identité de séance; les mouvements restent sur
   les blocs.

### Compilation

`CycleCompilerImpl` est générique : pour chaque semaine et chaque entrée de
`request.sessionOrder`, il sélectionne `SessionDefinition.id`, compile les
blocs, choisit le TM d’après `block.movementId`, arrondit et calcule les plaques.
Il supporte donc déjà une séance multi-mouvement sans branche Full Body.

Point fragile : `_blocksFor(...).singleWhere(session.id == sessionId)` et la
validation exigent une permutation exacte des IDs de séance. Les vieux ordres
de lifts (`press/deadlift/bench/squat`) ne peuvent pas piloter Full Body; les IDs
`monday/wednesday/friday` sont exposés bruts si la présentation ne dispose pas
des labels du schedule.

## Trace des options

### Warm-up

- Source : `classic/option_schemas.json` expose `include_warm_up`, groupe
  `warmup`, et les templates classiques référencent les composants
  `warmup_original_40_50_60`.
- Schéma Web : le bridge convertit tout paramètre visible en
  `options.<id>`; l’UI peut donc afficher et modifier le booléen.
- Requête : `main.ts` transporte la valeur dans `options`, mais le bridge ignore
  entièrement cette map lors de `_generate`.
- Compilateur : aucune propriété `includeWarmUp`, aucune condition de bloc; les
  warm-ups du template sont toujours compilés.
- Verdict : capacité UI présente, effet métier absent. L’option visible viole
  actuellement le principe « aucune option sans effet ».

### Joker Sets

- Source : mentions dans les inventaires Beyond/Forever, pas d’option schema
  Cycle `joker`, pas de composant exécutable Joker trouvé.
- Domaine : `RuntimeGateKind.jokerEligible` et la sérialisation des décisions
  existent, mais le codec source ne décode ni execution ni runtime gates pour
  les sets; aucun catalogue source ne contient `jokerEligible`.
- Requête/compilateur : aucun choix enable/disable Joker et aucune génération de
  sets Joker. Le compilateur ne fait que restituer les gates déjà présents.
- Verdict : primitive partielle, pas une capacité produit. Ne pas afficher
  Joker avant ajout de données catalogue et d’une sémantique générique.

### Deload

- Source : `include_deload` existe dans Classic/Beyond; les composants sont
  identifiés par `role: deload`.
- Requête : le Web mappe explicitement `options.include_deload` vers
  `includeDeload`; le bridge transmet le booléen.
- Compilateur : `_compileBlocks` exclut les blocs `deload` si false.
- Verdict : effet réel, mais implémentation spéciale et incomplète. L’option
  Full Body n’est pas publiée par son option schema; sa semaine 4 reste donc
  toujours active via la valeur par défaut true.

## Semaines et séances vides

Le compilateur crée toujours la semaine et toutes ses séances avant de filtrer
les blocs. Si une semaine/session ne contient que du deload et
`includeDeload=false`, la sortie conserve des sessions vides, voire une semaine
entière vide. Il n’existe ni prune générique ni invariant interdisant les
sessions vides après filtrage.

Pour Full Body, les semaines 4/8 contiennent aussi des composants assistance
dans les templates examinés : elles peuvent ne pas être totalement vides, mais
elles deviennent des semaines « assistance seule », ce qui n’équivaut pas
forcément à « supprimer le deload ». La sémantique attendue doit être déclarée :
désactiver seulement les blocs, ou retirer la semaine entière. Ce choix doit
venir du catalogue, pas d’une heuristique du front.

## kg/lb

- Le moteur préserve l’unité des maximums, exige la même unité pour request,
  incrément, barre et plaques, et rejette les profils mixtes.
- Les composants Full Body utilisent pour leurs charges soit un pourcentage du
  TM, soit bodyweight/unloaded : ils sont donc compatibles kg et lb.
- Aucun convertisseur kg↔lb n’existe ou n’est nécessaire dans le compilateur;
  un changement d’unité signifie fournir de nouvelles valeurs cohérentes.
- Limite Web : le schéma propose toujours barre 20 et plaques
  25/20/15/10/5/2.5/1.25, puis change seulement le tag d’unité. En lb cela crée
  un profil de 20 lb, non un profil impérial usuel. La correction appartient au
  snapshot matériel/catalogue Web, jamais au `CycleCompiler`.

## Compatibilité des anciens IDs

Le nouveau catalogue utilise au moins `overhead_press`, `bench_press`,
`back_squat`, `deadlift`, tandis que le POC/stockage historique emploie aussi
`press`, `bench`, `squat`, `barbell.back-squat`. Aucun registre d’alias partagé
n’existe à la frontière du moteur. Quelques mappings locaux subsistent dans le
legacy et les repositories, sans couvrir le bridge/catalogue statique.

Le compilateur doit rester strict sur les IDs canoniques. La compatibilité doit
être réalisée une seule fois lors de l’import/migration de snapshots, via un
`MovementIdAliasRegistry` versionné produit par le catalogue. Ne jamais ajouter
des comparaisons d’anciens IDs dans les calculs ou les widgets.

## Frontières exactes de correction

1. **Catalogue source** — publier les options uniquement sur les variantes où
   elles ont un sens; ajouter une primitive déclarative de condition aux
   composants/blocs, par exemple `enabledWhen: {optionEquals: {id, value}}`.
   Déclarer explicitement si Deload retire des blocs ou une phase/semaine.
2. **Codec/résolution (`training_engine`)** — décoder strictement cette
   condition dans un type générique (`BlockActivationCondition`), la conserver
   dans `PlanComponent`/`BlockDefinition`, et refuser option/condition inconnue.
   Aucun `if(templateId)` et aucun ID Warm-up/Joker codé ici.
3. **Contrat de requête** — ajouter `optionValues: Map<String, Object>` à
   `CycleRequest` (et au JSON v1 suivant/version incrémentée), rempli depuis le
   schéma validé. Conserver temporairement `includeDeload` comme adaptateur de
   compatibilité qui alimente la valeur canonique, puis le déprécier.
4. **Compilateur** — évaluer uniformément les conditions avant compilation des
   blocs. Après filtrage, appliquer une politique déclarée (`keepEmpty`,
   `dropSession`, `dropWeek`) provenant de la définition résolue. Les calculs de
   charge/plating restent inchangés.
5. **Joker** — avant toute UI, ajouter dans le catalogue des prescriptions
   exécutables : sets/blocs et gates strictement décodés. Décider si Joker est
   un bloc optionnel planifié ou une décision runtime après PR; modéliser ce
   choix dans le catalogue, pas dans TypeScript.
6. **Schedule/IDs** — renommer à terme `sessionMovementIds` en `sessionIds` dans
   le contrat moteur et fournir labels/tokens de schedule dans le schéma. Ajouter
   un registre d’alias seulement au chemin d’import de données historiques.
7. **Matériel** — fournir des profils kg/lb explicites dans le catalogue/bundle
   matériel et dériver l’incrément des plaques; aucune conversion implicite dans
   le moteur.

## Tests de fermeture proposés

- Full Body phases 1–3 : 8 semaines × 3 séances, blocs ciblés sur les bons
  mouvements, mêmes sorties native/bridge.
- Warm-up true/false : différence limitée aux blocs conditionnés, aucune autre
  charge modifiée.
- Deload false : politique de semaine vide vérifiée explicitement pour Classic,
  Beyond et Full Body.
- Joker : option absente tant qu’aucune recette exécutable; ensuite gate/sets et
  snapshot déterministes.
- Même requête kg et lb avec profils matériels cohérents : unités homogènes,
  arrondis et plaques propres à chaque profil.
- Import ancien `press/bench/squat` : migration vers IDs canoniques avant appel
  moteur; requête directe avec alias ancien rejetée.
