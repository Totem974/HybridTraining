# Décision de mise en veille de l’onboarding

## Décision

L’onboarding Base0 est gelé comme parcours de compatibilité pendant la
construction du cœur métier. Il continue de créer et lire les données attendues
par les bases existantes, mais ne porte ni recommandation, ni définition de
programme, ni promesse de programme Forever universel.

Le texte produit associé est : « Preset de compatibilité disponible pendant la
construction du moteur Forever. »

## Politique d’entrée

`SetupEntryMode` rend l’intention explicite :

- `legacyCompatibility` affiche le parcours existant avec un texte neutre ;
- `developmentBootstrap` crée, uniquement en flavor `dev`, un profil fictif et
  un plan déterministes ;
- `recommendationV2Disabled` réserve l’intention du futur moteur sans exposer
  d’interface incomplète. La politique retombe alors sur le parcours compatible.

Le flavor `prod` résout toujours l’entrée vers `legacyCompatibility`. Le mode
du flavor `dev` est une constante locale dans `lib/main_dev.dart` et n’ajoute
aucune dépendance.

## Preset historique

L’identifiant `forever-original-fsl-v1` et sa version 1 restent inchangés. Le
catalogue le marque `recommended = false`, compatible avec l’historique et
expérimental. La génération des cycles, la lecture des anciennes définitions,
les cycles déjà persistés et le format d’export/import ne changent pas.

## Hors périmètre

Cette décision n’implémente ni moteur de recommandation, ni nouvelle
bibliothèque, ni migration SQLite, ni nouveau programme, ni refonte visuelle.
