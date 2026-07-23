# Validation courante — Web statique Cycle

Date de vérification : 23 juillet 2026

Ce document décrit l'état observé dans l'arbre de travail courant. Le rapport
`static-web-g14-g15-2026-07-22.md` reste une preuve historique de son checkpoint ;
ses compteurs et ses tailles ne doivent plus être présentés comme l'état actuel.

## Confirmé

| Contrôle | Résultat observé |
| --- | --- |
| Tests unitaires Web | 72/72 réussis dans 16 fichiers |
| TypeScript | contrôle de types réussi dans le script de build |
| Build Vite | réussi, 29 modules transformés |
| Catalogue Web | version 2, hash `fnv1a64-0f5addced10d0b00` |
| Couverture catalogue déclarée | 17 templates Cycle, 25 variantes, 0 échec de compilation et 0 entrée Cycle non résolue |
| Matrice E2E | 78 réussies, 6 captures volontairement ignorées hors Chromium desktop |
| Matrice de variantes Chromium | 25 variantes publiques parcourues, 1/1 test réussi |
| Parité moteur | 21/21 variantes canoniques et 1/1 scénario Forever identiques entre Dart et JavaScript |

Le build statique courant contient neuf fichiers et pèse 1 766 758 octets
bruts. Mesures effectuées sur les fichiers produits par le build courant :

| Artefact | Brut | Gzip |
| --- | ---: | ---: |
| Bridge Dart JavaScript | 240 398 o | non remesuré |
| JavaScript UI | 53 626 o | 16 090 o |
| CSS | 27 637 o | 5 150 o |
| `catalog.bundle.json` | 283 734 o | 28 513 o |
| HTML `/cycle/` | 4 699 o | 1 320 o |

## À valider ou à rejouer

- La parité native/JavaScript est confirmée sur les 21 variantes canoniques
  publiées dans le manifeste et sur le scénario Forever existant.
- La matrice Playwright complète réussit sous Chromium desktop, Chromium mobile
  et WebKit. Les six cas ignorés correspondent uniquement aux captures
  réservées au projet Chromium desktop.
- Le parcours dynamique des 25 variantes visibles dans le catalogue réussit
  sous Chromium desktop. Les autres scénarios d'options, de partage,
  d'import/export, de FR/EN, de plaques et de responsive restent à rejouer
  et sont également couverts par la matrice multi-navigateurs complète.
- Les captures 1440, 390 et 320 px existent comme preuves locales, mais la
  comparaison visuelle humaine finale avec l'oracle reste requise avant toute
  bascule.
- Les performances locales n'ont pas été remesurées dans cette vérification ;
  celles du rapport du 22 juillet sont historiques.

## Conclusion

Les tests unitaires, le contrôle de types, le build, la parité moteur et la
matrice multi-navigateurs sont à jour et confirmés. La revue visuelle humaine
des captures demeure la dernière porte de validation ouverte.
Flutter Web et `/forever/` restent hors de toute suppression ou bascule sans
autorisation distincte.
