# Tests du composeur Forever

## Domaine

Les tests couvrent recette 2L/1A, insertion des protocoles, rôles, pairing,
blocage `needsReview`, programme autonome, projections TM liées aux nœuds,
sérialisation déterministe et migration v2. Le golden historique protège les
prescriptions du preset existant.

Un test source interdit toute décision Forever dépendant des semaines 3, 6, 10
ou 11 dans le nouveau compilateur.

## Interface

Les widget tests couvrent le contrôle segmenté accessible, conservation du profil
commun et des deux brouillons, disparition du résultat précédent, timeline,
protocoles automatiques, Anchor filtré, erreurs structurées, URL et restauration.
La matrice inclut desktop, 390 px, 320 px et text scale 2.0.

## E2E

Trois parcours vérifient Cycle, Forever export/rechargement et aller-retour entre
les modes. Ils doivent monter l'application et ses routes, pas seulement la page.

Les validations finales sont format, analyse, tests unitaires/widget/goldens,
intégration, build Web et captures desktop/mobile. Tout blocage d'environnement
est rapporté sans déclarer le scénario passant.
