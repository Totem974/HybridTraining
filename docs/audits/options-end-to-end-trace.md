# Audit de traçabilité des options Cycle

Date : 2026-07-22  
Périmètre : `catalog_src` → codec catalogue → `CycleEditorSchema` → requête TypeScript → contrat JSON v1 → bridge → `CycleRequest` Dart → `CycleCompiler` → `CycleResponse`.

## Conclusion

La chaîne n'est pas encore de bout en bout pour les options demandées. Le catalogue expose aujourd'hui surtout `include_warm_up` et `include_deload`. Le bridge les rend dans le schéma éditeur, mais l'objet générique `options` transmis par le navigateur est entièrement ignoré par `_generate`. Seul `include_deload` a un second chemin, hors de `options`, vers `CycleRequest.includeDeload`, et influence réellement le compilateur. Les paramètres de pourcentage constituent l'autre voie fonctionnelle : le navigateur les extrait dans `percentageParameters`, le bridge les décode et le compilateur les consomme.

Conséquence importante : une option booléenne ou énumérée peut actuellement être visible, modifiable, persistée dans l'état du formulaire et envoyée sans produire aucun changement métier. Cette situation concerne notamment `include_warm_up`. Elle contrevient à l'invariant « aucune option visible sans effet métier ».

## Chaîne actuelle

| Étape | État observé |
|---|---|
| Catalogue | Les schémas d'options sont des documents `optionSchemas`. `classic_531_options` déclare `include_warm_up` et `include_deload`; les schémas Beyond consultés ne déclarent que `include_deload` et des pourcentages. Aucun champ Joker, type de warm-up, bases haut/bas, type de deload ou skip warm-up n'existe. |
| Codec source | `CatalogSourceDocumentCodec.decodeOptionSchemas` valide une enveloppe et des paramètres génériques (`id`, `type`, `scope`, bornes, valeurs, conditions, présentation). Il retourne toutefois des `Map<String,Object?>`, pas des `CycleOptionDefinition` typés. Le vocabulaire générique sait représenter boolean/enumeration/integer/percentage/weight. |
| Schéma éditeur bridge | `LocalTrainingEngineBindings.cycleEditorSchema` lit le schéma brut et `_optionField` produit les champs visibles. Les types reconnus explicitement sont boolean, integer, percentage et `choice`; `enumeration` et `weight` tombent actuellement sur `text`. Les conditions catalogue `visibleWhen`/`enabledWhen` ne sont pas projetées dans les champs. |
| Formulaire Web | Les valeurs ont des chemins `options.<id>`. `main.ts` extrait correctement les champs `percentage` vers `percentageParameters`; il place aussi toutes les options dans `options`, en conservant leurs clés complètes `options.<id>`. |
| Contrat v1 | `cycle_request.schema.json` autorise `options` avec `additionalProperties: true`; il ne définit donc ni identité, ni type, ni dépendance conditionnelle pour ces options. `percentageParameters` est typé en basis points. `includeDeload` est un booléen de premier niveau obligatoire. |
| Bridge requête | `_generate` accepte la clé `options` dans la liste fermée des clés racine mais ne lit jamais sa valeur. Les pourcentages sont convertis en `Percentage`. Le booléen racine `includeDeload` devient `CycleRequest.includeDeload`. |
| Moteur | `CycleRequest` ne possède aucun contrat Warm-up ou Joker et ne possède qu'un booléen `includeDeload`. Le compilateur consomme les pourcentages paramétrés et filtre les blocs dont `role == 'deload'` lorsque `includeDeload == false`. |
| Réponse | `GeneratedCycle`/`CycleResponse` expose les blocs effectivement compilés, mais aucune section de réponse n'indique les options normalisées/effectives. Il est donc impossible de prouver depuis la réponse qu'une option générique a été comprise plutôt que silencieusement ignorée. |

## Matrice des options demandées

### Warm-up Original / Beyond et bases haut/bas kg/lb

Référence UI récupérée : `AdditionalOptions.js` propose `warmup = 0` (« Original ») ou `warmup = 1` (« Beyond 5/3/1 »). En mode Beyond, il affiche `lowerBase` et `upperBase`, exprimés dans l'unité courante (`kg` ou `lbs`).

| Élément | Catalogue | Schéma/UI | Contrat/requête | Moteur/réponse | Verdict |
|---|---|---|---|---|---|
| Activation warm-up | `include_warm_up` existe seulement dans `classic_531_options`, booléen, défaut `true`. | Champ généré dans le groupe warmup. | Envoyé seulement dans `options`; ignoré par le bridge. | Les blocs warm-up sont déjà inclus dans les week plans et ne sont jamais filtrés. | **Option morte.** |
| Original / Beyond | Absent. Les composants Original existent dans les plans (`warmup_original_40_50_60`), mais aucun choix de protocole n'est contractuel. | Absent. | Absent. | Aucun sélecteur de définition warm-up dans `CycleRequest`. | **Manquant de bout en bout.** |
| Base haut du corps | Absente. | Absente. | Absente; aucune `Weight` conditionnelle liée au type Beyond. | Absente. | **Manquante.** |
| Base bas du corps | Absente. | Absente. | Absente. | Absente. | **Manquante.** |
| Unité kg/lb | `weight` existe dans le vocabulaire générique, mais aucun paramètre correspondant. | `_optionField` ne rend pas encore `weight` comme poids. | `common.schema.json#/$defs/weight` existe et conviendrait; `CycleRequest.unit` existe. | `Weight` est typé avec `WeightUnit`. | **Primitives disponibles, liaison absente.** |

Travail contractuel requis : une identité non localisée pour le protocole (`original`/`beyond`), deux poids typés et visibles/requis uniquement pour Beyond, puis une primitive moteur de configuration warm-up. Il ne faut pas représenter les bases par de simples nombres sans unité ni les déduire dans TypeScript.

### Joker enabled et maximum +5 % à +30 %

Référence UI récupérée : `jokerMax = 0` désactive Joker; sinon les valeurs autorisées sont 1 à 6, présentées `+5 %`, `+10 %`, ..., `+30 %`.

| Élément | Catalogue | Schéma/UI | Contrat/requête | Moteur/réponse | Verdict |
|---|---|---|---|---|---|
| Joker activé | Aucun paramètre Joker dans les schémas d'options inspectés. Le vocabulaire de présentation contient pourtant le groupe `joker`. | Aucune colonne métier ne peut être alimentée par le catalogue. | Absent. | Aucun champ dans `CycleRequest`, aucun rôle/bloc Joker produit à partir d'une option. | **Manquant.** |
| Maximum Joker | Absent; aucune borne 5..30 ni pas de 5. | Absent. | Absent. | Absent. | **Manquant.** |

Le modèle recommandé est un booléen d'activation plus un pourcentage en basis points, borné 500..3000, pas 500, visible/requis seulement si activé. La recette métier doit résider dans une primitive/composant catalogue résolu et dans le moteur; le front ne doit ni fabriquer les séries Joker ni traduire un index 1..6 en pourcentage.

### Deload enabled / type / skip warm-up

Référence UI récupérée : activation séparée; six types (`Deload 1` à `Deload 5`, `High Intensity`); `Skip Warmup` visible lorsque le deload est actif et que le type est l'un des cinq deloads ordinaires.

| Élément | Catalogue | Schéma/UI | Contrat/requête | Moteur/réponse | Verdict |
|---|---|---|---|---|---|
| Deload activé | `include_deload` existe dans Classic et plusieurs schémas Beyond. Certains Beyond n'autorisent que `true`. | Champ généré. | Deux représentations concurrentes : `options.include_deload` (ignorée) et `includeDeload` racine (consommée). `main.ts` recopie actuellement la première dans la seconde. | `CycleRequest.includeDeload` filtre les blocs `deload`. | **Fonctionnel, mais doublonné et fragile.** |
| Type de deload | Absent. | Absent. | Absent. | Les blocs deload sont fixés par le template/composant résolu. | **Manquant.** |
| Skip warm-up pendant deload | Absent. | Absent. | Absent. | Aucun contrat ne permet de filtrer uniquement le warm-up des séances de deload. | **Manquant.** |

Le filtrage actuel agit au niveau des blocs et conserve la structure des semaines/séances; un test doit préciser si un cycle sans deload doit supprimer la semaine/séance de deload ou seulement ses blocs. Il faut une seule représentation canonique de l'activation. Une option cataloguée normalisée par le bridge vers un contrat moteur typé évitera le double chemin actuel.

### Full Body phase

Référence UI récupérée : pour la variante Full Body « Original », un champ Phase choisit Phase One, Two ou Three. La source propose par ailleurs les variantes `Original`, `Updated` et `Full Boring` avec d'autres réglages.

| Élément | Catalogue | Schéma/UI | Contrat/requête | Moteur/réponse | Verdict |
|---|---|---|---|---|---|
| Phase 1/2/3 | Les phases existent, mais comme trois templates séparés (`classic_full_body_phase_1`, `_2`, `_3`), chacun avec sa variante et ses plans/phases résolus. | Le catalogue les affiche comme templates distincts; il n'existe pas de champ Phase sous un template Full Body commun. | La phase est implicitement portée par `templateId`, pas par une option. | Le moteur compile correctement le template choisi et ses `CatalogPhase`, y compris `repeatCount`. | **Fonctionnel au moteur, non conforme au contrat/UX source.** |
| Variant Original/Updated/Full Boring | Pas de modèle équivalent unifié dans le schéma `classic_extended_full_body_options`, qui ne contient que `training_max_ratio`. | Absent comme réglage Full Body. | Absent. | Les recettes correspondantes ne sont pas exposées comme choix compatibles d'une définition unique. | **Manquant ou modélisé différemment.** |

Il faut décider au niveau catalogue si les trois phases restent trois templates assumés ou deviennent des variantes/options d'une famille Full Body. Cette décision ne doit pas être simulée par un `if templateId` dans le bridge ou le front. Si la parité UI source exige un champ Phase, le catalogue doit fournir une relation de famille et les choix autorisés; le moteur doit continuer à recevoir une définition résolue unique.

## Codecs et contrats concernés

- `catalog_src/**/option_schemas*.json` : ajouter les paramètres et conditions, avec IDs stables, labels et groupes de présentation.
- `packages/training_engine/lib/features/training_catalog/data/catalog_source_document_codec.dart` : conserver le vocabulaire fermé; tester les nouveaux types/conditions et idéalement retourner un modèle typé plutôt que des maps brutes.
- `packages/training_engine/lib/features/cycle_generation/domain/cycle_option_schema.dart` : les primitives nécessaires existent en partie, mais ne sont pas la frontière effective du bridge.
- `packages/training_engine/lib/features/cycle_generation/domain/cycle_contract.dart` : ajouter des contrats métier typés Warm-up/Joker/Deload, ou un snapshot d'options résolues validé; ne pas ajouter des maps opaques ignorables.
- `contracts/v1/cycle_editor_schema.schema.json` : sait déjà exprimer choix, booléens, poids et conditions; vérifier que toutes les projections sont générées.
- `contracts/v1/cycle_request.schema.json` : remplacer ou fermer `options.additionalProperties: true`; supprimer la double autorité de `includeDeload`; modéliser les poids avec unité et les pourcentages en basis points.
- `contracts/v1/cycle_response.schema.json` / snapshot : inclure suffisamment d'information canonique pour prouver les options effectives, ou prouver leur effet par les blocs/séries et le hash.
- `packages/training_engine_web_bridge/lib/src/engine_bindings.dart` : `_optionField` doit prendre en charge `enumeration`, `weight` et les conditions; `_generate` doit décoder/valider chaque option reconnue et refuser toute option inconnue au lieu d'ignorer `options`.
- `apps/web_generator/src/main.ts` : ne doit plus recopier ou transformer des règles métier. Il doit sérialiser les valeurs selon les chemins/contrats fournis, sans convertir Joker, sélectionner un protocole ou calculer des bases.

## Tests requis avant de déclarer une option supportée

1. **Catalogue/codec**
   - décodage positif de chaque nouveau paramètre, borne et condition;
   - rejet des IDs, types, valeurs et clés inconnus;
   - couverture de compatibilité par template/variante, notamment options Beyond et Full Body.

2. **Schéma éditeur bridge**
   - snapshot par template vérifiant groupes, labels, types, valeurs par défaut et valeurs autorisées;
   - visibilité des bases seulement pour Beyond;
   - visibilité du maximum Joker seulement si Joker est actif;
   - visibilité de `skip warm-up` seulement pour les types de deload compatibles;
   - phase Full Body seulement pour la famille/variante autorisée.

3. **Contrats JSON v1**
   - fixtures valides kg et lb;
   - bornes Joker 5 et 30 acceptées, 0/35 rejetées lorsque le champ est actif;
   - bases manquantes rejetées en Beyond et interdites en Original;
   - option inconnue rejetée à la frontière;
   - round-trip des types TypeScript générés, sans modèle manuel divergent.

4. **Bridge → moteur**
   - test spy/fake ou test de compilation prouvant que chaque valeur JSON devient la primitive Dart attendue;
   - test différentiel où modifier une option modifie le snapshot/hash ou produit explicitement la même sortie lorsque la règle le prévoit;
   - aucune option acceptée sans lecture effective.

5. **Moteur pur**
   - Original vs Beyond : blocs/séries warm-up exacts, bases haut/bas et conversion d'unité;
   - Joker off/on et maximum 5/10/.../30, avec incompatibilités et avertissements structurés;
   - deload off, chaque type, skip warm-up, structure semaine/séance définie;
   - Full Body phases 1/2/3 et répétitions de phase, snapshots canoniques.

6. **Parité native/JS**
   - matrice minimale : 2 warm-ups × kg/lb, Joker off + six maxima, deload off + six types avec skip pertinent, trois phases Full Body;
   - comparaison JSON canonique exacte, y compris blocs, séries, charges, plaques, avertissements, snapshot et hash.

7. **Web/Playwright**
   - champs conditionnels visibles/cachés au clavier et sur 1440/390/320;
   - changement d'option puis génération avec preuve dans le programme;
   - rechargement du brouillon sans perte de type/unité;
   - aucune requête externe.

## Critère de fermeture

Une option n'est « supportée » que si un test démontre les cinq maillons suivants avec la même valeur sémantique : champ catalogue → champ éditeur → JSON v1 validé → primitive moteur consommée → différence observable et canonique dans la réponse/snapshot. Tant que ce test n'existe pas, l'option doit rester cachée plutôt qu'être affichée sans effet.
