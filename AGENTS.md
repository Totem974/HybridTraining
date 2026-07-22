# AGENTS.md — HybridTraining

## 1. Fondation stable

Les éléments suivants existent et ne doivent pas être reconstruits :

```text
catalog_src → catalog.db
catalog.db → CatalogResolver
ResolvedCycleDefinition + CycleRequest → CycleCompiler
GeneratedCycle → training.db
```

Le POC Forever reste présent mais gelé pendant cette phase.

## 2. Priorité active

```text
PARITÉ VISUELLE ET FONCTIONNELLE DE /cycle
AVANT TOUT NOUVEAU TRAVAIL FOREVER
```

La référence visuelle est constituée des captures fournies, du miroir HTML/CSS local et de la page de référence :

```text
https://fivethreeone.app/calculator
```

Les captures fournies ont autorité sur les détails de disposition.

## 3. Périmètre

Modifier uniquement ce qui est nécessaire à `/cycle` :

- bloc Charges / Weight ;
- bloc Modèle / Template ;
- Options supplémentaires ;
- Plaques et barre ;
- Planification ;
- Output ;
- rendu Programme ;
- responsive, localisation et accessibilité ;
- contrats applicatifs strictement nécessaires à ces blocs.

Préserver :

- catalogue ;
- générateur Cycle ;
- persistance ;
- route et page Forever ;
- navigation Cycle/Macrocycle.

Ne pas développer de nouvelle capacité Forever pendant cette phase.

## 4. Règle d’architecture

L’interface ne contient aucune règle d’entraînement.

```text
catalog.db
→ CycleEditorSchema
→ CycleEditorState
→ widgets
→ CycleRequest
→ CycleCompiler
```

Interdictions :

```text
if (templateId == ...)
switch(templateId)
liste statique de templates
pourcentages codés dans les widgets
schedule codé dans les widgets
calcul de TM dans les widgets
calcul de plating dans les widgets
fallback vers le moteur legacy
```

Une option absente du contrat doit être ajoutée au catalogue ou à une primitive générique, pas simulée dans la présentation.

## 5. Langage visuel

Reproduire le langage de la référence sans copier son code, ses actifs, sa marque ou sa police archivée.

Cibles :

```text
fond général      #181818
cartes             #323232
contrôles          gris moyen
accent             #2C9EFF
texte              clair
largeur max        environ 900 px
rayon cartes       environ 18 px
écart sections     environ 24 px
desktop            deux colonnes
mobile             une colonne sous environ 771 px
```

Utiliser les tokens Flutter partagés du projet.

## 6. Bloc Weight

- Le sélecteur `1 RM / Training Max / Rep Max` occupe toute la largeur intérieure.
- Les mouvements sont alignés à gauche comme sur la référence.
- Une ligne contient : repère visuel, nom, répétitions si pertinentes, charge et unité.
- Mode 1 RM : répétitions fixées à 1.
- Mode Training Max : saisie directe du TM.
- Mode Rep Max : répétitions modifiables par mouvement et charge modifiable.
- Le calcul du 1RM estimé et du TM reste dans le domaine/application.
- Un seul ratio TM global est affiché pour les mouvements principaux.
- Aucun ratio TM principal à côté de chaque mouvement.
- Les ratios propres à un template restent dans le bloc Template/Options.
- Unité kg/lb en contrôle segmenté.

## 7. Bloc Template

Présentation en lignes :

```text
Template     valeur sélectionnée >
Variante     valeur sélectionnée >
Option       valeur sélectionnée >
```

- libellé à gauche ;
- valeur et chevron à droite ;
- options dynamiques sous les deux premières lignes ;
- aucune grande liste native qui déborde visuellement ;
- toutes les données viennent du catalogue.

## 8. Additional Options

Desktop : trois colonnes principales exactement :

```text
WARM-UP | JOKER SETS | DELOAD
```

Mobile : empilement lisible.

- Warm-up, Joker et Deload sont pilotés par le catalogue.
- Les champs conditionnels apparaissent sous leur colonne.
- Assistance et conditioning, lorsqu’ils existent, apparaissent dans une seconde rangée ou une carte dédiée, sans casser les trois colonnes principales.
- Aucune option visible sans effet métier.
- Les incompatibilités sont évaluées par le domaine/application.

## 9. Plaques et barre

- Conserver les compteurs `− / quantité / +` pour chaque plaque.
- Conserver la sélection kg/lb et le profil matériel.
- Afficher le poids de la barre à gauche dans la ligne inférieure.
- Afficher le total maximal à droite si disponible.
- Supprimer le champ utilisateur `Incrément d’arrondi`.
- Supprimer le champ texte/résumé libre `Plaques par côté`.
- L’incrément effectif est dérivé du matériel disponible dans l’application/domaine.
- Le rendu des plaques par série reste un résultat du moteur de plating.

## 10. Planification

Remplacer les champs techniques bruts par des contrôles visuels.

- La fréquence vient du template/schedule.
- Une fréquence unique est affichée comme valeur verrouillée.
- Plusieurs fréquences autorisées utilisent un contrôle segmenté.
- L’ordre est représenté par de petites cases/tokens.
- Avant les icônes finales, utiliser :
  - `OP` Overhead Press ;
  - `BP` Bench Press ;
  - `SQ` Squat ;
  - `DL` Deadlift.
- Pour une séance multi-mouvements, afficher un token de groupe, par exemple `SQ+BP`.
- Ne permettre que les réordonnancements valides du schedule.
- Ajouter les options `Bastard work order` et `3/5/1 week order` uniquement lorsqu’elles sont exposées par le catalogue.
- Conserver une date de départ si le moteur en a besoin, avec un vrai date picker compact.
- Ne jamais afficher d’IDs ou de listes brutes telles que `1,2,4,5` ou `overhead_press,...`.

## 11. Output

Le bloc contient :

- titre du programme ;
- option `Show plating / Afficher les plaques` ;
- autres options uniquement si elles sont réellement supportées ;
- bouton principal `Générer`.

Ne pas afficher `Générer et sauvegarder`.

La persistance interne existante peut rester, mais le libellé et le parcours Web restent ceux d’un générateur.

## 12. Programme

Le programme doit ressembler à la référence :

```text
SEMAINE 1
├── carte séance OP
├── carte séance DL
├── carte séance BP
└── carte séance SQ
```

Chaque carte affiche :

- nom utilisateur du mouvement ;
- date si disponible ;
- blocs avec titres lisibles ;
- séries sous la forme `reps × charge` ;
- plaques en petites pastilles seulement si `Show plating` est actif ;
- assistance sous forme de nom d’exercice et répétitions.

Interdictions :

- objets Dart bruts ;
- JSON brut ;
- IDs techniques ;
- chaînes comme `{type: fixed, count: 5}` ;
- détails de debug.

Responsive :

- quatre colonnes lorsque la largeur le permet ;
- réduction progressive ;
- une colonne lisible sur mobile.

## 13. Travail parallèle

Avant de lancer les agents, le lead :

1. gèle `CycleEditorState` et les intents nécessaires ;
2. extrait chaque bloc dans un fichier/widget distinct ;
3. définit les tokens visuels communs ;
4. attribue des chemins exclusifs.

Aucun fichier modifié simultanément par deux agents.

Répartition :

1. Weight ;
2. Template ;
3. Additional Options ;
4. Plating ;
5. Scheduling ;
6. Output + Program ;
7. responsive + FR/EN + accessibilité ;
8. intégration + revue read-only.

Le lead possède :

- page de composition ;
- contrats publics ;
- design tokens ;
- composition root ;
- exports ;
- commits.

## 14. Validation

Tests ciblés pendant les blocs.

Gate final :

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
flutter build web --release
```

Validation visuelle : 1440 px, 390 px et 320 px dans Chrome.

Vérifier dans Chrome :

- Weight ;
- Template ;
- Additional Options ;
- Plating ;
- Scheduling ;
- Output ;
- Program ;
- changement de plusieurs templates ;
- génération ;
- affichage/masquage des plaques ;
- aucune erreur console.

## 15. Git

- Préserver les changements utilisateur.
- Jamais de `git reset --hard`.
- Jamais de push forcé.
- Petits commits cohérents par bloc.
- Aucun push sans autorisation explicite.
