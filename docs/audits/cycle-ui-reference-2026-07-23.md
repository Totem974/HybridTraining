# Audit UI Cycle — référence locale

Date : 23 juillet 2026
Mise à jour de la validation : 23 juillet 2026
Source observée : capture locale de `fivethreeone.app/calculator` fournie par le
propriétaire du dépôt.

## Référence figée

L'oracle source exact contient 35 scénarios versionnés. Ils couvrent les états
et interactions relevés sur la référence locale et servent à vérifier la
nouvelle interface sans en reprendre l'identité graphique.

## Responsive observé

| Largeur | Composition | Hauteur observée | Débordement horizontal |
| --- | --- | ---: | ---: |
| 1440 px | Weight/Template puis Scheduling/Output en deux colonnes | 5031 px | 0 px |
| 390 px | Tous les blocs empilés | 6377 px | 0 px |
| 320 px | Tous les blocs empilés | 6344 px | 5 px |

HybridTraining reprend la composition et l’empilement, mais refuse le
débordement de 5 px observé à 320 px. Les cibles interactives conservent une
hauteur minimale de 44 px.

## Matrice de comportement

| Bloc | Contrôles de référence | Décision HybridTraining |
| --- | --- | --- |
| Weight | unités, Training Max, 1RM, 1RM estimé, ratio TM | Conserver les modes et valeurs exposés par `CycleEditorSchema` |
| Template | modèle, variante et paramètres conditionnels | Exposer les 19 templates et 37 variantes Cycle publics du catalogue |
| Additional Options | warm-up, bases Beyond, Joker, deload et skip warm-up | Afficher/masquer selon les dépendances du moteur ; bloc repliable |
| Plating & Barbell | compteurs −/+, poids de barre, total maximal | Conserver les compteurs moteur ; bloc repliable |
| Scheduling | fréquence, ordre des mouvements, ordre 3/5/1 | Conserver les schedules, les compatibilités moteur et le réordonnancement des séances |
| Output | titre, QR, plaques et actions | Conserver titre, plaques, import/export et partage existants |
| Program | semaines, séances, blocs, séries et plaques | Rendre la réponse moteur sans transformation métier |

## Identité et droits

Aucun logo, visuel, texte promotionnel, police ou actif de la référence n’est
réutilisé. La marque reste HybridTraining avec un symbole géométrique original
et une palette ambre/ardoise. La référence sert uniquement à valider la
hiérarchie fonctionnelle, les gestes et le responsive.

## Macrocycle

Le sélecteur Cycle/Macrocycle de la page statique dirige Macrocycle vers
`/forever`, l’oracle Flutter existant. Aucune page Forever statique ni nouvelle
règle métier n’est introduite.

## Mesures après refonte

Mesures locales effectuées sur le port 4176 :

| Scénario | Médiane | p95 |
| --- | ---: | ---: |
| Premier chargement local | 559,49 ms | 566,11 ms |
| Génération Standard | 92,5 ms | 101,4 ms |
| Génération BBB | 92,5 ms | 106,4 ms |

| Artefact | Brut | Gzip |
| --- | ---: | ---: |
| Bridge Dart JavaScript | 297 058 o | 92 114 o |
| JavaScript UI | 60 714 o | 18 243 o |
| CSS | 29 467 o | 5 524 o |
| `catalog.bundle.json` | 432 646 o | 37 361 o |
| `catalog.db` | 1 548 288 o | 162 125 o |

## Validation fonctionnelle finale

Le catalogue validé contient 58 documents, 22 templates bruts et 41 variantes
brutes. Sa surface Cycle publique contient 19 templates et 37 variantes.

| Contrôle | Résultat |
| --- | ---: |
| Parité Cycle native | 37/37 |
| Parité Cycle JavaScript | 37/37 |
| Parité Forever | 1/1 |
| Tests moteur | 186/186 |
| Tests bridge | 54/54 |
| Tests Web unitaires | 98/98 |
| Tests des contrats | 16/16 |
| Tests E2E | 85 réussis, 26 ignorés intentionnellement |

Les 26 cas E2E ignorés sont des projets ou tests non applicables. Ils ne sont
pas des échecs.
