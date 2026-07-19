# Définition de fin du POC

Statut au 18 juillet 2026, source code : `2080a27` puis branche de maintenance.

## CURRENT

- application locale, hors ligne et sans compte ;
- onboarding, choix kg/lb, plan 3/4 jours et preset de compatibilité `forever-original-fsl-v1` ;
- séance guidée, reprise, résultats, notes, historique et Training Max ;
- SQLite version 3 et sauvegarde version 3 couvrant les tables v1, v2 et runtime v3 ;
- flavors Android `dev` et `prod`.

## POC_TARGET

Le POC est clos uniquement lorsque les parcours ci-dessus passent sur le Redmi Note 7, que FR et EN sont réellement raccordés, que les grands textes restent utilisables, et que formatage, analyse, tests, intégration et deux builds passent sur le même SHA.

## Limites acceptées

- `forever-original-fsl-v1` reste un preset de compatibilité expérimental, pas une recommandation universelle Forever.
- Beginner Prep School est documenté et son domaine v2 est testé, mais reste non sélectionnable tant que le parcours v2 n'est pas raccordé.
- Les Leader/Anchor/7th Week complets et la bibliothèque Forever exhaustive sont `FUTURE`.
