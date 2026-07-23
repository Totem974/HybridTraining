# Audit UI Cycle — référence locale

Date : 23 juillet 2026
Source observée : capture locale de `fivethreeone.app/calculator` fournie par le
propriétaire du dépôt.

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
| Template | modèle, variante et paramètres conditionnels | Conserver les 25 variantes publiques du catalogue |
| Additional Options | warm-up, bases Beyond, Joker, deload et skip warm-up | Afficher/masquer selon les dépendances du moteur ; bloc repliable |
| Plating & Barbell | compteurs −/+, poids de barre, total maximal | Conserver les compteurs moteur ; bloc repliable |
| Scheduling | fréquence, ordre des mouvements, ordre 3/5/1 | Conserver les schedules et compatibilités moteur |
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

Mesures Chromium locales, 5 échauffements et 30 itérations :

| Scénario | Médiane | p95 |
| --- | ---: | ---: |
| Premier chargement local | 549,07 ms | 561,14 ms |
| Génération Standard | 92,50 ms | 108,20 ms |
| Génération BBB | 91,80 ms | 101,40 ms |

Le build Vite produit un HTML de 5,87 kB, un CSS de 28,80 kB
(5,42 kB gzip) et un JavaScript UI de 54,41 kB (16,34 kB gzip).
