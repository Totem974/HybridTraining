# Audit des composants de séance Forever - 2026-07-18

## Résultat

Les composants de séance ont été séparés en rôles mesurables sans imposer le
modèle de série aux durées, distances, intervalles, circuits ou totaux de reps.
Les règles proviennent de *5/3/1 Forever*, pages PDF 18-46 et 256-266, avec
recoupement du programme Beginner Prep School, pages 50-56.

## Décisions

- Mobilité, warm-up général et warm-up barbell sont trois notions distinctes.
- Jumps/throws forment un bloc athlétique explosif, jamais un bloc conditioning.
- Main et supplemental sont distincts ; certains programmes n'ont aucun
  supplemental.
- Assistance Forever utilise push, pull et single-leg/core. Les listes Original,
  les variantes Beyond et les choix utilisateur ne sont pas fusionnés.
- Easy conditioning est requis par le système ; hard conditioning est optionnel
  et subordonné au template, au but et à la récupération.
- Leader/Anchor modifie les volumes relatifs ; ce n'est pas un simple libellé.
- Sled/Prowler est incompatible avec single-leg assistance dans la même
  planification prescrite.
- La source de règle est obligatoire sur chaque prescription générée.

## Points prêts pour le contrat de code

Les taxonomies `SessionBlockRole`, `SetRole`, `ExerciseCategory`,
`AssistanceCategory`, `ConditioningIntensity` et `RequirementLevel` sont assez
petites pour la première implémentation tout en couvrant les natures observées.
Le modèle de mesure discriminé évite les faux sets pour un mile, une marche de
30 minutes, un farmer walk de 240 yards ou un circuit de 20 minutes.

## Limites et NEEDS_REVIEW

- Les rampes barbell exactes restent propres au preset ; aucune rampe universelle
  n'est établie.
- La fréquence easy/hard locale doit être extraite de chaque programme.
- Les substitutions médicales et contre-indications nécessitent une politique
  produit ; elles ne sont pas déduites de l'ouvrage.
- `SetRole` pourra être étendu lors de la revue détaillée des autres templates,
  mais aucun rôle hypothétique ne doit être ajouté aujourd'hui.

## Protection des références

Aucun PDF, texte substantiel, capture, fichier décompilé, donnée personnelle ou
secret n'a été copié dans le dépôt. Les documents sont des spécifications
structurées et des synthèses courtes.

