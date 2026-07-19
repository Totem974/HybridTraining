# Rapport final — Lignées de programmes

## Objectif

Remplacer les familles exclusives par des générations, concepts, révisions et
presets versionnés.

## Résultat

Le domaine Dart pur distingue désormais Original, Beyond et Forever comme
générations. Le catalogue central porte les concepts, leurs origines prouvées ou
inconnues, les révisions documentées et l’unique preset exécutable
`forever-original-fsl-v1`. La factory refuse tout identifiant non disponible
avant l’ouverture d’une transaction de création.

## Compatibilité

Les champs JSON `family` et la valeur `classic` restent acceptés ; `classic` est
converti en `original`. Le schéma SQLite reste en version 1 et l’identifiant du
preset est inchangé.

## Limites

L’origine de First Set Last, Boring But Big et Joker Sets reste `NEEDS_REVIEW`
tant que la première apparition n’est pas établie sans ambiguïté dans les sources.
