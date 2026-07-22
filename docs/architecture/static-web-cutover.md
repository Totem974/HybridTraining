# Plan de cutover — générateur Cycle Web statique

## Décision recherchée

Faire de la page statique `/cycle/` l'entrée publique du générateur Cycle tout
en conservant Flutter et la page Forever comme oracle et solution de repli.
Cette phase ne supprime ni Flutter Web ni Forever et n'autorise aucun push ou
déploiement par elle-même.

## Invariants avant bascule

- le package `training_engine` reste l'unique moteur consommé par Flutter et
  par le bridge ; aucune règle d'entraînement n'est dupliquée en TypeScript ;
- le catalogue natif et `catalog.bundle.json` proviennent du même build et ont
  le même hash logique ;
- les six opérations JSON v1 refusent les clés inconnues et retournent des
  enveloppes versionnées et des erreurs structurées ;
- les 23 variantes Cycle sont identiques entre oracle, Dart natif et bridge ;
- la fixture Forever est générée réellement par le bridge, même si aucune page
  Forever statique n'est livrée ;
- les données utilisateur restent dans IndexedDB/localStorage et aucune
  requête métier ne sort du navigateur ;
- les parcours clavier, FR/EN, 1440/390/320 et l'affichage des plaques sont
  vérifiés dans Chromium ; un contrôle WebKit est archivé ;
- le build publié ne contient que les fichiers nécessaires au runtime.

## Séquence de bascule

1. Geler le commit candidat, le hash catalogue, les oracles et les versions des
   outils dans le rapport de validation.
2. Exécuter l'intégralité des gates Dart, Flutter, contrats, catalogue, Web,
   Playwright et parité depuis un checkout propre.
3. Régénérer `dist`, reprendre les mesures raw/gzip et les 30 mesures de temps
   décrites dans le rapport G14/G15.
4. Examiner les captures 1440, 390 et 320 px à côté des captures de référence ;
   enregistrer les écarts acceptés, sans importer marque, police ou actifs de
   la source d'inspiration.
5. Publier le dossier statique sous une URL de prévisualisation limitée à
   `/cycle/`. Vérifier les routes profondes, types MIME, cache et en-têtes de
   sécurité sans ajouter de backend applicatif.
6. Effectuer une recette manuelle Standard, BBB et Two-day rotation, puis
   rechargement, changement FR/EN, export et restauration locale.
7. Obtenir l'autorisation explicite de bascule. Pointer alors `/cycle/` vers le
   build statique ; laisser la route Forever sur Flutter.
8. Observer erreurs JavaScript, échecs de chargement d'artefacts et intégrité
   du hash catalogue. Aucune donnée personnelle ni télémétrie distante ne doit
   être ajoutée pour cette observation.
9. Après une période définie par le propriétaire produit, décider séparément
   du retrait de Flutter Web. Cette décision est hors du présent chantier.

## Retour arrière

Le retour arrière consiste uniquement à repointer `/cycle/` vers le build
Flutter validé. Les conditions de retour immédiat sont : divergence moteur,
catalogue/hash incohérent, génération impossible pour une variante supportée,
perte de brouillon local, régression d'accessibilité bloquante ou requête
externe inattendue.

Avant toute bascule, conserver :

- l'artefact Flutter exact et son commit ;
- le catalogue correspondant ;
- les fixtures v1 et les rapports de gates ;
- une procédure de restauration de route testée ;
- la version des enveloppes IndexedDB.

Le rollback ne doit pas tenter de convertir silencieusement une enveloppe de
stockage inconnue. Elle est conservée pour récupération/export et ignorée avec
une erreur structurée par une version incompatible.

## Critères de décision finale

La bascule est autorisable seulement lorsque le rapport G14/G15 ne contient
plus de preuve manquante : parité Cycle et Forever verte, build reproductible,
Playwright Chromium et WebKit vert, captures revues, mesures publiées et
artefact `dist` régénéré sans fichiers de debug inutiles. L'autorisation doit
être explicite ; la réussite technique seule ne vaut ni déploiement ni
suppression de Flutter.
