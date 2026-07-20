# Règles de compatibilité Forever

## Modèle

Une `PairingRule` identifie révisions source/cible, rôles, statut, fréquences,
plage de TM, matériel, niveau, objectifs, restrictions par lift et référence.
Les statuts sont `recommended`, `allowed`, `restricted`, `forbidden` et
`needsReview`.

Le validateur retourne un `CompatibilityResult` et des problèmes portant code,
message, chemin/nœud, niveau et suggestion.

## Couverture exécutable initiale

Une seule relation Leader → Anchor est activée : les révisions Original + FSL
du preset historique `FV-236`. Elle est limitée à quatre jours et au contrat TM
déjà revu. C2 reprend C1. Aucun autre Leader compatible revu n'étant disponible,
l'option « autre Leader pour C2 » reste désactivée.

`FV-141` est un programme autonome et n'entre dans aucun pairing.

## Rejets bloquants

- rôle de révision différent du rôle du slot ;
- entrée documentaire, indisponible ou `needsReview` ;
- fréquence, TM, équipement ou niveau incompatible ;
- pairing absent, interdit ou non revu ;
- protocole obligatoire absent ou altéré ;
- programme autonome placé dans une recette ;
- Powerlifting présenté comme génération Forever.

Les tags génériques ne créent jamais une compatibilité implicite.
