# Domaine canonique multi-génération

Le contrat Dart pur actuellement conservé sous
`lib/features/programs/domain/v2` est le domaine canonique en cours de migration
vers Core v5. Il sépare explicitement :

- l'origine historique d'un concept ;
- l'édition source (`Original`, `Powerlifting`, `Beyond`, `Forever`) ;
- la génération du ruleset exécuté ;
- les identifiants stables de concept, révision et blueprint ;
- le type structurel d'un bloc, son rôle et la finalité typée d'un protocole
  7th Week.

`MethodGeneration` n'est défini qu'ici. `program_identity.dart` expose désormais
un alias de migration vers ce type canonique afin de préserver les imports et
identifiants persistants historiques sans maintenir un second enum concurrent.

## Mouvements et prescriptions

`MovementId` est une valeur extensible. Les quatre mouvements historiques sont
des constantes, au même titre que power clean et front squat, mais aucune boucle
du nouveau domaine ne dépend d'une liste enum fermée.

`ActivityPrescription` représente séries/répétitions/charge, séries au poids du
corps, répétitions totales, durée, distance, rounds, completion ou objectif
qualitatif. La prescription conserve position, mouvement ou activité, type,
règle, édition, génération, référence exacte et détails d'arrondi. Le résultat
réel est un objet séparé.

## Validation et compatibilité

Le validateur agrège doublons, références manquantes, versions absentes,
transitions impossibles, fréquences incompatibles, générateurs manquants, règles
non revues et provenance absente. Il rejette aussi toute prescription dont la
cible ou la source est incomplète.

`ProgramV1Adapter` reste un adaptateur de migration : il convertit les anciens
catalogues vers ces types, conserve les identifiants persistants et renseigne
explicitement édition et génération. Il ne constitue plus un second domaine.
