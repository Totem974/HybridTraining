# Tests du composeur Forever

## Domaine

Les tests couvrent recette 2L/1A, insertion des protocoles, rôles, pairing,
blocage `needsReview`, programme autonome, projections TM liées aux nœuds,
sérialisation déterministe et migrations v2 → v3 → v4 et v3 → v4. Le golden historique protège les
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

## Résultats du 2026-07-20

- `dart format --set-exit-if-changed .` : réussi ;
- `flutter analyze` : réussi, aucun diagnostic ;
- `flutter test --reporter compact` : réussi, 393 tests ;
- Google Chrome 150.0.7871.129 avec ChromeDriver 150.0.7871.124 : cinq
  scénarios E2E sur cinq réussis en 35,4 secondes ;
- Mozilla Firefox : cinq scénarios E2E sur cinq réussis en 34,7 secondes ;
- le scénario Forever termine M1 et M2, clôture la série, recharge une nouvelle
  page depuis le stockage navigateur réel et vérifie les TM 62,5 puis 65 ;
- Microsoft Edge : non exécuté ; Flutter 3.44.6 envoie la capability
  `browserName: edge`, refusée par EdgeDriver 150 qui attend `MicrosoftEdge`.
  Ce blocage relève du SDK Flutter et aucun résultat Edge n'est déclaré ;
- validations et builds Android : explicitement reportés à un chantier
  ultérieur et non bloquants pour ce lot.
