# Générateur de macrocycles Forever

## Décision

Le générateur vit dans `lib/features/programs/domain/v2/generation/`. Il est en
Dart pur et ne dépend ni de Flutter, ni de SQLite. Il consomme un
`ProgramBlueprintSnapshot` exécutable et une `AthletePlanConfiguration`, puis
produit un `GeneratedTrainingPlan` versionné.

Le snapshot complète le modèle composable D1 avec les seules informations
nécessaires à l'exécution : ordre et nombre de blocs, nombre de cycles,
semaines, séances, blocs hétérogènes, mouvements et séries. Il conserve aussi
une représentation JSON canonique du blueprint. La copie JSON est détachée de
la source et les collections du contrat sont non modifiables.

## Invariants

- chaque `ReviewedRule` doit être `RuleStatus.verified` ; une règle
  `needsReview` ou `undocumented` bloque la génération ;
- toutes les politiques actives du blueprint doivent être revues ;
- la séquence exécutable doit correspondre exactement à la séquence D1 ;
- les nombres de cycles et de semaines sont obligatoires et viennent du
  snapshot, sans défaut Leader/Anchor ;
- un bloc `seventhWeek` porte obligatoirement un `SeventhWeekPurpose` ;
- options, assistance et conditioning sont rejetés s'ils ne figurent pas dans
  les ensembles autorisés du snapshot ;
- les TM restent ceux de l'entrée : les progressions et tests sont des
  `PlannedTrainingEvent`, jamais une mutation implicite ;
- les identifiants sont dérivés de la position et des identifiants stables ; le
  seed fait partie du résultat ;
- `LocalDate` reconstruit uniquement des dates civiles locales et n'effectue
  aucune conversion UTC.

## Modèle de sortie

`GeneratedTrainingPlan` contient, dans l'ordre : blocs, cycles, semaines,
séances, blocs de séance et prescriptions. Chaque prescription conserve TM,
charge brute, incrément, charge arrondie et source. Les transitions entre blocs
sont matérialisées. Les événements de progression sont émis après chaque cycle
Leader ou Anchor ; TM Test et PR Test sont émis par les blocs 7th Week typés.

Le JSON de sortie utilise `schemaVersion: 1`. Toute évolution incompatible doit
augmenter cette version et disposer d'une migration ou d'un nouvel adapter.

## Compatibilité historique

`OriginalFslMacrocycleAdapter` traduit `forever-original-fsl-v1` vers le nouveau
contrat sans modifier `OriginalFslProgram`. Les pourcentages, répétitions,
performance sets, FSL 3/5 séries et arrondis utilisent le contrat historique.
Un test compare chaque prescription produite par les deux chemins.

## Extension

Un nouveau preset doit fournir un snapshot versionné intégralement sourcé. Le
générateur n'interprète pas un titre de programme et n'invente ni warm-up,
assistance, conditioning, fréquence, Leader, Anchor ou transition. Les règles
encore `NEEDS_REVIEW` restent documentaires et ne peuvent pas activer le preset.
