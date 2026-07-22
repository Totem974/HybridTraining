# Audit de normalisation du catalogue — templates, variantes, phases et options

État inspecté : 22 juillet 2026, branche
`codex/local-dart-engine-static-web-v1`. Cet audit est strictement analytique :
aucun catalogue, moteur, bundle ou schéma n'a été modifié.

## Sources et empreinte observées

L'inspection croise `catalog_src`, `apps/web_generator/public/catalog.db`,
`catalog.bundle.json`, le manifeste Web et les références du bridge. Le
manifeste courant annonce :

- catalogue v2, schéma v1 ;
- hash `fnv1a64-d7517fe07a23e362` ;
- 354 entrées d'inventaire, toutes classifiées ;
- 19 templates et 23 variantes exécutables ;
- 9 schémas d'options, 8 schedules, 53 composants ;
- 0 référence manquante, 0 template non résolu, 0 primitive non supportée.

Ces compteurs prouvent la cohérence référentielle comprise par le builder. Ils
ne prouvent pas une taxonomie produit correcte : des objets morts, des IDs
historiques et des concepts placés au mauvais niveau peuvent rester valides.

## Taxonomie cible utilisée pour l'audit

- **Template** : famille de programme reconnaissable, stable dans l'URL, les
  brouillons et les snapshots.
- **Variante** : recette exécutable alternative au sein d'une famille ; le
  choix change la structure, pas seulement une valeur de formulaire.
- **Phase** : segment temporel ordonné d'une même recette. Une phase n'est pas
  un deuxième sélecteur de template.
- **Option** : paramètre modifiable sans changer l'identité de la recette.
- **Schedule** : distribution des séances/mouvements ; ce n'est ni une variante
  du programme ni une option énumérée concurrente.

## Inventaire exhaustif des recettes exécutables

| Template | Variante(s) | Forme | Options | Schedule(s) | Observation |
| --- | --- | --- | --- | --- | --- |
| `classic_531` | `four_day`, `three_day_rotation`, `two_day_rotation` | 4 semaines | `classic_531_options` | 4 j ; rotation 3 j ; deux schedules 2 j | fréquence encodée à la fois dans variante et schedule |
| `classic_bodyweight` | `four_day` | 3 semaines | `classic_531_options` | 4 j fixe | variante singleton redondante mais bénigne |
| `classic_boring_but_big` | `same_lift_5x10` | 4 semaines | `classic_531_options` | 4 j fixe | le 5×10 est structurel, correctement dans la recette |
| `classic_jack_shit` | `main_lift_only` | 4 semaines | `classic_531_options` | 4 j, rotation 3 j, paire 2 j | schedule réellement sélectionnable |
| `classic_periodization_bible` | `four_day` | 3 semaines | `classic_531_options` | 4 j fixe | variante singleton |
| `classic_simplest_strength` | `original`, `powerlifting` | 4 semaines | `classic_simplest_strength_options` | 4 j fixe | variantes structurelles légitimes ; options de mouvements sont pourtant mono-valeur |
| `classic_triumvirate` | `four_day` | 3 semaines | `classic_531_options` | 4 j fixe | variante singleton |
| `classic_for_beginners` | `original_progression` | 4 semaines | `classic_extended_beginner_options` | full-body 3 j | famille distincte légitime ; partage un schedule trop large avec Full Body |
| `classic_full_body_phase_1` | `phase_1` | phase `phase_1`, 4 semaines répétées 2 fois | `classic_extended_full_body_options` | full-body 3 j | phase encodée trois fois |
| `classic_full_body_phase_2` | `phase_2` | phase `phase_2`, 4 semaines répétées 2 fois | idem | idem | phase encodée trois fois |
| `classic_full_body_phase_3` | `phase_3` | phase `phase_3`, 4 semaines répétées 2 fois | idem | idem | phase encodée trois fois |
| `beyond_boring_but_big` | `same_lift_5x10_50_two_cycles` | cycle 1, cycle 2, deload | `beyond_bbb_same_lift_options` | 4 j fixe | phases temporelles légitimes ; identité trop détaillée dans l'ID de variante |
| `beyond_first_set_last` | `amrap_four_day_two_cycles` | cycle 1, cycle 2, deload | `beyond_main_variation_options` | 4 j ou rotation 3 j | l'ID dit 4 jours alors que 3 jours est autorisé |
| `beyond_fives_progression` | `main_lifts_four_day_two_cycles` | cycle 1, cycle 2, deload | idem | 4 j ou rotation 3 j | même contradiction d'ID |
| `beyond_pyramid` | `four_day_two_cycles` | cycle 1, cycle 2, deload | idem | 4 j ou rotation 3 j | même contradiction d'ID |
| `powerlifting_classic_531` | `four_day_531_deload` | 4 semaines | `powerlifting_classic_531_options` | 4 j fixe | recette cohérente, mais deload obligatoire exposé comme option |
| `forever_bbb_leader` | `fives_pro_5x10_50` | 3 semaines | `classic_531_options` | 4 j fixe | cycle interne Forever, pas un choix public `/cycle/` |
| `forever_original_531_anchor` | `standard_531` | 3 semaines | idem | 4 j fixe | cycle interne Forever |
| `forever_7th_week_protocol` | `deload_four_day`, `tm_test_four_day` | 1 semaine | idem | 4 j fixe | cycles internes Forever |

Le total est bien 19 templates / 23 variantes. Quatre des 23 variantes sont des
primitives de composition Forever. Or `getCatalogIndex` énumère actuellement
tous les records `templates` sans notion de surface : elles peuvent donc être
présentées dans le sélecteur Cycle. La couverture exhaustive masque ici une
fuite de scope produit.

## Anomalies prioritaires

### P0 — Full Body confond template, variante et phase

La même identité `phase_N` est portée par :

1. le template `classic_full_body_phase_N` ;
2. sa variante singleton `phase_N` ;
3. sa phase interne `phase_N`.

Cela transforme une famille « 5/3/1 Full Body Training » en trois templates et
rend les trois niveaux indiscernables pour le front, la persistance et les
analytics locaux. Chaque phase contient quatre semaines avec `repeatCount: 2`
et `minimumDurationMonths: 2`, ce qui confirme un bloc temporel, pas trois
marques de programme indépendantes.

Normalisation recommandée, préservant le comportement de génération actuel :

```text
template  classic_full_body_training
variants  phase_1 | phase_2 | phase_3
phase interne  training_block (ou suppression de l'enveloppe si inutile)
```

Une alternative plus fidèle au sens éditorial serait une seule variante
`original` contenant les phases 1→2→3. Elle change cependant la granularité de
génération (six mois au lieu d'une phase sélectionnable) et exige une décision
produit explicite. La première proposition est donc la migration compatible.

La phase 4 (`OR-034`) est classée `documentation`, tout comme « More Full Body
Training » et « More Squatting ». Le schéma
`classic_extended_full_body_options` cite pourtant `or.full_body.phase_4`.
Phase 4 ne doit pas être créée artificiellement comme recette tant que ses
composants exécutables ne sont pas modélisés ; sa règle doit être retirée du
schéma exécutable ou documentée comme provenance non exécutable.

### P0 — Le schedule Full Body mélange mouvements principaux et assistance

`classic_extended_three_day_full_body.sessions[].movementIds` contient à la
fois `back_squat`, `bench_press`, `deadlift`, `overhead_press` et les exercices
`dumbbell_press`, `dumbbell_row`, `chin_up`. Ces trois derniers ne figurent pas
parmi les six `movements` canoniques ; ce sont des exercices d'assistance.

Conséquences observables : le schéma éditeur peut demander des max pour des
exercices d'assistance, les tokens de planification peuvent afficher trop de
mouvements, et le schedule devient responsable du contenu d'une séance alors
que les composants le décrivent déjà. Il faut limiter le schedule aux cibles
principales, et laisser l'assistance aux composants/plans d'assistance.

Le même schedule est utilisé par `classic_for_beginners` et les trois Full
Body, alors que leurs composants et leurs besoins de ciblage ne sont pas
identiques. Soit le schedule devient une grille de séances neutre avec cibles
principales explicites par recette, soit deux schedules nommés sont nécessaires.

### P0 — IDs de mouvement historiques `squat`

Les schedules centraux utilisent `squat`, mais le registre canonique expose
`back_squat`. L'ID historique apparaît dans :

- `schedule_four_day_fixed` ;
- `schedule_three_day_rotating` ;
- `schedule_two_day_multi_movement_option_one` ;
- `schedule_two_day_rotating_four_lifts` ;
- le schedule mort `schedule_original_for_beginners_fixed_three_day`.

Le moteur tolère manifestement cet alias, puisque la compilation exhaustive
passe, mais la frontière catalogue n'est pas normalisée. Il faut migrer les
sources vers `back_squat` et conserver un alias de lecture versionné pour les
brouillons/snapshots historiques, jamais deux identités actives.

### P1 — Objets préparés mais non référencés

Deux schémas et trois schedules sont construits dans le catalogue sans être
référencés par aucune variante :

- `classic_extended_two_day_options` ;
- `original_for_beginners_options` ;
- `classic_extended_two_day_option_one` ;
- `classic_extended_two_day_option_two` ;
- `schedule_original_for_beginners_fixed_three_day`.

Les deux schedules `classic_extended_two_day_option_*` dupliquent
sémantiquement les schedules actifs `schedule_two_day_multi_movement_option_one`
et `schedule_two_day_rotating_four_lifts`. Le schéma
`classic_extended_two_day_options.schedule_option` duplique en plus le choix de
schedule (`paired`/`rotating`). Il faut choisir le schedule comme autorité,
migrer d'éventuelles valeurs persistées, puis retirer les trois objets
concurrents du bundle runtime.

`schedule_original_for_beginners_fixed_three_day` utilise aussi l'ancien ID
`squat`. `original_for_beginners_options` et
`classic_extended_beginner_options` modélisent deux fois une progression de
débutant (`original/intermediate` contre `beginner/intermediate`) avec des
defaults incompatibles. Le second est le schéma actif ; le premier doit être
considéré comme un ancien ID, pas comme une seconde autorité.

### P1 — Options qui ne sont pas réellement optionnelles

- `beyond_bbb_same_lift_options.include_deload`,
  `beyond_main_variation_options.include_deload` et
  `powerlifting_classic_531_options.include_deload` n'autorisent que `true`.
  Un switch serait trompeur : le champ doit être verrouillé/masqué ou devenir
  structurel dans la variante.
- `bbb_percentage` vaut uniquement 5000. C'est une constante de la recette
  `same_lift_5x10_50`, pas une option utilisateur dans cet état du catalogue.
- les quatre paramètres de mouvements de Simplest Strength n'acceptent chacun
  qu'une valeur. Ils décrivent la recette ; ils ne doivent pas apparaître comme
  choix tant qu'aucune alternative n'est cataloguée.
- plusieurs `training_max_ratio` sont fixes à 9000, d'autres autorisent
  8500/9000, avec scope `global` ou `perMovement`. La règle UI requiert un seul
  ratio global pour les mouvements principaux : le catalogue doit distinguer
  un ratio utilisateur d'une constante/contrainte de recette.

### P1 — Variante et schedule se recouvrent

`classic_531` encode la fréquence dans les variantes `four_day`,
`three_day_rotation`, `two_day_rotation`, puis autorise un ou plusieurs
schedules. Pour `two_day_rotation`, deux organisations très différentes sont
permises. À l'inverse, les IDs Beyond disent `four_day_two_cycles` tout en
autorisant aussi `schedule_three_day_rotating`.

Règle proposée : une variante ne mentionne la fréquence dans son ID que si la
structure des semaines change réellement. Sinon, garder une variante de recette
et laisser `scheduleIds` porter fréquence et ordre. Cette migration est plus
invasive que Full Body car elle change les 23 oracles ; elle doit venir après
les alias de compatibilité.

### P1 — Cycles internes Forever exposables comme templates Cycle

Les trois templates `forever_*` sont nécessaires à `ForeverComposer`, mais ne
doivent pas être proposés dans `/cycle/`. Ajouter au contrat catalogue une
visibilité/surface explicite, par exemple :

```text
surface: cyclePublic | foreverInternal
```

Le bridge doit filtrer `CatalogIndex` sur `cyclePublic`, tout en conservant les
records internes pour `generateMacrocycle`. Ne pas inférer ce scope depuis le
préfixe `forever_` : le préfixe est une convention, pas un contrat.

## Plan de migration des IDs

| Ancienne identité | Cible/traitement | Compatibilité nécessaire |
| --- | --- | --- |
| `classic_full_body_phase_1/phase_1` | `classic_full_body_training/phase_1` | alias de lecture template+variante |
| `classic_full_body_phase_2/phase_2` | `classic_full_body_training/phase_2` | idem |
| `classic_full_body_phase_3/phase_3` | `classic_full_body_training/phase_3` | idem |
| phase interne `phase_N` | `training_block` ou aplatissement | snapshot v1 conservé ; nouveau snapshot v2 |
| mouvement `squat` | `back_squat` | alias de lecture aux frontières v1 |
| `classic_extended_two_day_option_one` | schedule actif paired | mapping explicite d'ID |
| `classic_extended_two_day_option_two` | schedule actif rotating | mapping explicite d'ID |
| `schedule_original_for_beginners_fixed_three_day` | retirer ou remplacer par schedule Beginner canonique | seulement si aucune enveloppe persistée ne le référence |
| `original_for_beginners_options` | `classic_extended_beginner_options` | mapper `original` vers `beginner` après validation sémantique |
| option `schedule_option` | `scheduleId` | convertir `paired`/`rotating` vers IDs canoniques |

La migration ne doit jamais réécrire silencieusement les fixtures v1. Elle doit
introduire une table d'alias versionnée à la lecture, produire de nouveaux
snapshots v2 avec IDs canoniques, puis retirer les alias uniquement après une
fenêtre de compatibilité explicite. Les clés concernées sont les brouillons
IndexedDB, configurations sauvegardées, exports JSON, snapshots et références
Forever.

## Ordre recommandé

1. Geler le hash et les 23 oracles actuels comme corpus de migration.
2. Ajouter `surface/visibility` et empêcher l'exposition des templates Forever
   dans l'index Cycle.
3. Canonicaliser `squat` → `back_squat` avec alias de lecture.
4. Séparer mouvements principaux et assistance dans le schedule Full Body.
5. Regrouper les trois templates Full Body sous une famille et publier la table
   d'alias correspondante.
6. Supprimer du runtime les schémas/schedules non référencés après preuve
   d'absence de références persistées.
7. Transformer les paramètres mono-valeur en contraintes structurelles ou
   champs en lecture seule, sans créer de choix fictifs.
8. Dans un lot distinct, décider si fréquence relève de Variante ou Schedule,
   puis renommer les IDs Beyond contradictoires.
9. Reconstruire `catalog.db` et `catalog.bundle.json`, prouver l'égalité du hash
   logique, régénérer les types et les 23 oracles, et ajouter des tests de
   migration ancien→canonique.

## Gates de normalisation à ajouter

- tout `movementIds` de schedule appartient au registre de mouvements, jamais
  au registre d'exercices ;
- aucun schéma d'options ou schedule runtime n'est non référencé sans drapeau
  explicite `internal`/`deprecated` ;
- un paramètre affichable possède au moins deux valeurs possibles ou est marqué
  `readOnly` ;
- un seul mécanisme sélectionne un schedule (pas `schedule_option` en parallèle) ;
- les templates internes Forever sont absents de l'index public Cycle ;
- aucun triplet template/variante/phase ne répète la même identité conceptuelle ;
- tous les anciens IDs de la table de migration sont testés en lecture et tous
  les nouveaux exports n'émettent que les IDs canoniques.

## Conclusion

Le catalogue est exhaustif et compilable, mais pas encore normalisé comme
catalogue produit. Le cas Full Body est la dette principale : trois niveaux
d'identité dupliqués, un schedule mêlant mouvements et assistance, et une phase
4 de provenance documentaire citée par un schéma exécutable. La seconde dette
est la coexistence d'objets préparés et actifs qui décrivent les mêmes schedules
ou options. Ces anomalies doivent être corrigées dans les sources et leurs
alias de migration, pas compensées par le front TypeScript.
