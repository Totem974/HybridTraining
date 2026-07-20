# Architecture du composeur Forever

## Frontière de mode

`PlanningMode.cycle` et `PlanningMode.forever` sont deux parcours métier. Un
`CommonTrainingProfile` immutable porte uniquement les saisies partagées. L'état
applicatif conserve deux brouillons indépendants et synchronise le profil commun.

```text
CommonTrainingProfile
├── CyclePlanningConfiguration → moteur Classic existant
└── ForeverPlanningConfiguration
    ├── standaloneProgram → générateur canonique autonome
    └── macrocycle → ForeverSequenceCompiler → moteur canonique
```

Les widgets ne reçoivent que des choix filtrés, des nœuds compilés et des
problèmes structurés. Ils ne décident ni des rôles, ni des protocoles, ni des TM.

## Autorité Forever

Le flux cible est :

```text
ProgramLibrary
  → MacrocycleRecipeDefinition + CycleSelection
  → ForeverSequenceCompiler
  → CanonicalPlanGenerator (adaptateur de prescriptions)
  → CompiledTrainingPlan / VersionedTrainingPlan
```

`forever-2l1a` est la seule recette macrocycle exécutable du premier incrément.
Elle insère un Deload après les deux Leaders et un TM Test final. Les protocoles
sont des nœuds distincts, jamais des cycles artificiels.

## Migration progressive

`CanonicalPlanGenerator._forever` reste temporairement l'adaptateur de
prescriptions historiques. La structure qu'il reçoit vient désormais de la
recette compilée. Le calculateur POC et l'UI consomment la même séquence compilée.
`OriginalFslMacrocycleAdapter` reste une compatibilité historique et ne décide
plus d'une nouvelle séquence.

## Invariants

- une révision non revue ou documentaire n'est jamais exécutable ;
- une sélection porte un rôle explicite ;
- un pairing est autorisé uniquement par une règle explicite et sourcée ;
- les protocoles obligatoires sont auto-insérés et non supprimables ;
- les décisions TM référencent une instance de cycle, un nœud et une frontière ;
- le même payload v3 produit la même séquence ordonnée.
