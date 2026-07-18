# Spécification de composition d'une séance Forever

## Ordre canonique

1. mobilité / warm-up général ;
2. jumps/throws ;
3. warm-up barbell du premier main lift ;
4. main work ;
5. supplemental work, s'il existe ;
6. assistance push, pull, single-leg/core selon prescription ;
7. conditioning si planifié avec la séance ;
8. notes et clôture.

Forever autorise une composition avancée où jumps/throws sont intercalés avec les
séries d'approche et éventuellement les 1-2 premières work sets, maximum 3 reps
par insertion (PDF 26-27). Elle doit être explicitement activée, pas déduite.

## Taxonomie minimale proposée

```text
SessionBlockRole
  mobilityWarmup | jumpsThrows | barbellWarmup | mainWork |
  supplementalWork | assistance | conditioning | recovery | transition

SetRole
  warmup | main | prSet | goalSet | supplementalFsl | supplementalSsl |
  supplementalBbb | supplementalBbs | supplementalWidowmaker | test | deload

ExerciseCategory
  squat | hinge | horizontalPush | verticalPush | pull | singleLeg |
  core | jump | throw | locomotion | mobility | recovery | neck

AssistanceCategory
  push | pull | singleLegCore | uncategorizedNeck

ConditioningIntensity
  easy | hard

RequirementLevel
  requiredBySystem | requiredByPreset | recommended | optional | prohibited
```

Les identifiants persistés sont en anglais, stables et non dérivés des libellés
français/anglais.

## Contrat d'activité

Toute activité possède : identifiant, rôle, ordre, requirement level, source de
règle, prescription, résultat et statut. La mesure est une union discriminée :

| Nature | Prescription/résultat requis |
|---|---|
| série chargée | exercice, charge ou pourcentage/TM, reps, set role |
| total reps | exercice/catégorie, cible min/max, reps réalisées |
| durée | durée cible/plage, durée réalisée |
| distance | distance, unité, distance réalisée |
| intervalles | nombre, distance/durée par intervalle, repos |
| circuit | tours, activités ordonnées, reps/durée par activité, limite temps |
| jump/throw | mouvement, contacts/throws, hauteur/distance/charge optionnelle |
| note/évaluation | critère, valeur/texte, réussite et motif |

Champs transversaux nécessaires : `prescription`, `result`, `load`, `reps`,
`duration`, `distance`, `notes`, `order`, `status`, `ruleSource`. Les champs non
applicables restent absents et ne reçoivent pas zéro.

## États d'exécution

`planned`, `inProgress`, `completed`, `skipped`, `substituted`, `failed`,
`notApplicable`. Un skip ou une substitution conserve l'élément canonique, la
raison, la source et le remplacement éventuel ; aucune donnée invalide ou ignorée
ne disparaît silencieusement.

## Compatibilités

- Un programme peut ne pas avoir de supplemental (PDF 27-29).
- Supplemental : barbell et proche du main lift ; assistance : catégorie plus
  large et charge non pilotée par le TM sauf règle locale.
- Leader : supplemental plus volumineux, assistance/jumps/hard conditioning
  réduits ; Anchor : volume barbell réduit, intensité et autres blocs accrus
  (PDF 29-31).
- Mobilité reste stable entre Leader/Anchor sauf besoin explicite.
- 7th Week : aucun supplemental, assistance limitée (PDF 31).
- Gros volume squat/deadlift : éviter lower-back assistance et heavy rows.
- Prowler/sled : supprimer single-leg assistance.
- Un preset local peut renforcer ou réduire ces recommandations ; la provenance
  et la priorité de règle doivent être déterministes.

## Repos

Le repos n'est pas une constante globale. Il peut appartenir à une série, un
intervalle ou un circuit. Jumps/throws exigent un repos suffisant pour rester
explosifs (PDF 23). Running après adaptation peut utiliser 3:1 repos:travail
(PDF 265). Beginner Prep School interdit de précipiter les séries même avec une
cible de durée (PDF 53). Toute valeur absente reste `NEEDS_REVIEW` au lieu d'être
inventée.

