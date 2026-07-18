# Décision sur le programme par défaut

## Décision

La famille par défaut de Hybrid 5/3/1 est **5/3/1 Forever**. Le seul template
activable dans ce lot est **Original 5/3/1 + First Set Last**. Son identifiant
persistant reste `forever-original-fsl-v1` et la version de définition reste 1.

Ce template ne représente pas tout le catalogue Forever. Beyond et Classic sont
des familles distinctes ; Boring But Big, Full Body et les autres entrées
Forever restent indexées ou `NEEDS_REVIEW` et ne peuvent générer aucun cycle.

## Modèle d'identité

L'identité métier sépare :

- la famille : Forever, Beyond ou Classic ;
- l'identifiant stable du template ;
- la version de la définition ;
- la clé de libellé français/anglais ;
- le statut de validation documentaire ;
- les références structurées aux pages du livre et du PDF.

Le snapshot fournit cette identité aux écrans. Le moteur Original + FSL continue
d'utiliser un Training Max à 90 %, dans la plage documentée de 85 à 90 %, sans
modifier les pourcentages, l'arrondi ni les cinq séries FSL existantes.

## Compatibilité SQLite

Le schéma reste en version 1. Les cycles existants continuent de référencer
`forever-original-fsl-v1`. Une ancienne ligne `program_definitions` dont le JSON
ne contient pas les nouvelles métadonnées est décodée avec un fallback
déterministe basé sur cet identifiant ; elle n'est ni remplacée ni supprimée.
