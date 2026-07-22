# Validation du POC Forever — 22 juillet 2026

- Branche : `codex/forever-macrocycle-poc-v1`.
- Catalogue publié immuable : version 2, distincte du checkpoint Cycle v1.
- Définition publiée : BBB, deux Leaders puis un Anchor.
- Composition réelle : Leader, Leader, 7th Week Deload, Anchor, TM Test.
- Cycles enfants générés : 5 avec le `CycleCompiler` commun.
- Persistance : brouillon dans `workspace.db`, macrocycle et snapshots dans
  `training.db`, relecture après fermeture et réouverture vérifiée.
- Training Max : +5 lb haut du corps et +10 lb bas du corps après les phases
  de progression, valeurs projetées jusqu'au TM Test.
- Couverture : 354/354 entrées classifiées, 19 templates Cycle, 23 variantes
  Cycle et 1 définition Forever ; tous les compteurs d'échec sont à zéro.
- Tests Flutter : 363 réussis.
- Analyse Flutter, format, intégrité Git et build Web release : réussis.

## Navigateur

Chrome est installé et a été lancé par `flutter drive`, mais le pilote n'a
produit aucun résultat avant la limite bornée de quatre minutes. La seconde
méthode Flutter a confirmé que les tests d'intégration Web ne sont pas pris en
charge directement sur un device Chrome. Le parcours court équivalent est
couvert par le test d'intégration `/forever`, et les états mobile/desktop,
FR/EN et l'accessibilité sont couverts par les tests Widget. Chrome n'est pas
déclaré passant.
