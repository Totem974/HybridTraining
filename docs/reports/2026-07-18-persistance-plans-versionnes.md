# Rapport — persistance des plans versionnés — 2026-07-18

## Résultat

Le schéma v1 a été évalué insuffisant pour le modèle composable. Le schéma v2
relationnel est additif et conserve la voie historique v1. Il persiste identité
et version du blueprint, snapshot et provenance, macrocycle, blocs, cycles,
séances multi-mouvements, prescriptions avec Training Max, performances et
transitions avec progression proposée/confirmée.

## Couverture automatisée

- création d’une base vide v2 ;
- migration v1 vers v2 sans perte ;
- interruption et rollback de migration ;
- snapshot immuable ;
- plusieurs blocs et plusieurs mouvements dans une séance ;
- reprise après fermeture/réouverture ;
- rollback de création invalide ;
- transition atomique et évènement de Training Max ;
- export v2 et import/dry-run d’une sauvegarde v1 ;
- conservation du cycle `forever-original-fsl-v1` sans plan v2 synthétique ;
- contraintes d’unicité relationnelles.

## Limites déclarées

La présentation n’active pas encore la création de plans composables : le dépôt
v2 est prêt pour l’intégration du générateur. Les tables v1 restent la seule voie
pour terminer les séances historiques. Le retour vers une ancienne version de
l’application exige la restauration d’une sauvegarde v1 ; aucune migration
destructive v2 vers v1 n’est fournie.
