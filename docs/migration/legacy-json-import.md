# Import JSON historique

## État

`BLOCKED_BY_SAMPLE` — aucun export réel anonymisé de l'ancienne application n'a
été trouvé dans `.SOURCE`. Son schéma ne sera pas deviné depuis l'APK ou la
mémoire.

## Pipeline disponible

La Base0 fournit les contrats pour :

1. décoder un objet JSON sans modifier le fichier source ;
2. détecter un format avec un gestionnaire explicite ;
3. valider sa version et son contenu ;
4. produire les erreurs et chaque champ ignoré ;
5. exécuter une simulation sans écriture ;
6. remettre les données validées à une unique opération atomique.

Une fixture manifestement fictive, `test/fixtures/fictitious_import_v1.json`,
teste ce parcours. Elle n'est pas présentée comme compatible avec l'ancienne
application.

## Échantillon nécessaire

Fournir une copie anonymisée d'un export original contenant, si possible :

- paramètres et unité ;
- quatre mouvements et historiques de Training Max ;
- au moins un programme actif ;
- une séance planifiée et une séance terminée ;
- séries réussies, échouées et notes ;
- un record ;
- une salle et son matériel si le format les possède.

Remplacer noms, notes libres et dates personnelles par des valeurs fictives sans
changer les clés, types, niveaux d'imbrication ni valeurs d'énumération. Ne jamais
ajouter l'échantillon réel au dépôt Git.

## Travail après réception

- calculer et conserver localement une empreinte du fichier ;
- documenter le format et ses variantes ;
- écrire un détecteur dédié à l'ancien package uniquement dans la migration ;
- ajouter des fixtures anonymisées minimales ;
- mapper chaque champ ou le signaler comme ignoré avec justification ;
- tester rollback, doublons, réimport et versions inconnues ;
- exposer simulation et rapport avant le bouton de confirmation.

Le format d'export propre à Hybrid Training est `hybrid-training-backup`, version
1, avec `format`, `schemaVersion`, `exportedAt`, `appVersion` et `payload`.

