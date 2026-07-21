# Gouvernance du catalogue et publication des recettes Cycle

Statut : proposition normative pour le chantier Cycle 5/3/1
Portée : définitions, variantes, politiques, schedules, supplemental, assistance
et configurations personnalisées publiables
Hors portée : choix du schéma SQLite, implémentation du générateur et interface
utilisateur

## Décision

Le produit distingue des axes indépendants : l'autorité, le cycle de vie,
`reviewStatus`, l'implémentation, l'exécution, la visibilité, la licence et la
preuve structurée. Une recette documentée n'est pas exécutable par sa seule
présence dans le catalogue, et une recette exécutable n'est pas nécessairement
canonique.

Toute génération doit utiliser un snapshot immuable et versionné. Le snapshot
contient uniquement des règles dont la provenance, la licence, les dépendances
et les validations sont compatibles avec son niveau d'autorité. Une règle
marquée `NEEDS_REVIEW` dans une source ou un audit est persistée avec
`reviewStatus: needsReview`. Une telle règle, une règle ambiguë ou une règle
sans preuve suffisante ne peut jamais être publiée, résolue par fallback ou
rendue visible comme option exécutable.

## Vocabulaire normatif

Les mots **DOIT**, **NE DOIT PAS**, **DEVRAIT** et **PEUT** ont un sens
normatif.

### Autorité de recette

`canonical`

- Reproduit une prescription suffisamment complète d'une source autoritative.
- Chaque règle exécutable possède un identifiant stable, une provenance typée,
  une localisation précise, une version et un statut de revue positif.
- Les champs canoniques sont verrouillés dans la définition publiée. Un
  utilisateur peut dériver une configuration, mais ne modifie jamais le
  snapshot canonique.
- Une nouvelle interprétation ou correction produit une nouvelle version. Elle
  ne réécrit pas une version déjà publiée.

`compatible`

- Extension dont la compatibilité avec une recette est explicitement validée,
  sans être prescrite comme partie canonique de cette recette.
- La provenance décrit la preuve de compatibilité et ne prétend pas que le
  livre en fait un default.
- Une extension compatible est sélectionnée explicitement. Elle n'est jamais
  appliquée comme fallback silencieux.

`userCustom`

- Configuration ou recette créée ou modifiée par l'utilisateur.
- Peut dépasser les structures 5/3/1, par exemple représenter un split
  Push/Pull/Legs, à condition de ne jamais porter un badge, nom, provenance ou
  description laissant croire qu'elle est canonique 5/3/1.
- Les éléments dérivés conservent la référence facultative au parent et la
  version d'origine, mais portent une identité propre et une autorité
  `userCustom`.
- Toute modification d'un champ verrouillé d'un snapshot canonique crée un
  dérivé personnalisé ; elle ne modifie pas le parent.

### Cycle de vie

Le champ de cycle de vie utilise exclusivement `draft`, `inReview`, `approved`,
`published`, `retired` et `rejected` :

- `draft` : modifiable et non sélectionnable pour une génération produit ;
- `inReview` : contenu gelé pour la revue, mais non publiable en l'état ;
- `approved` : revue achevée, en attente du gate de publication ;
- `published` : snapshot immuable, adressable et distribuable ;
- `retired` : non proposé pour une nouvelle configuration, mais conservé pour
  la lecture et la reproduction historique compatibles ;
- `rejected` : refusé par le workflow et non distribuable.

`retired` ne peut être supprimé tant qu'un snapshot, une migration ou un export
pris en charge le référence. `superseded` est une relation de succession, pas un
statut de cycle de vie.

### Statut de revue

Le contrat canonique du champ `reviewStatus` contient exactement :

- `needsReview` : preuve ou interprétation insuffisante ;
- `confirmed` : preuve suffisante pour la règle déclarée ;
- `rejected` : revue achevée avec refus de la règle.

Aucune autre valeur n'appartient à cet axe. En particulier :

- `partial` appartient à `implementationStatus` ;
- `blocked` appartient à `implementationStatus` ou `executionStatus`, selon le
  bloqueur ;
- `outOfScope` décrit la nature ou la portée produit ;
- `hidden`, `internal` et `visible` appartiennent à la visibilité ;
- la présence, la localisation et la qualité d'une preuve sont des données de
  provenance structurées.

`published + reviewStatus != confirmed` est une combinaison invalide pour une
règle exécutable. Un blocage d'implémentation ou d'exécution invalide également
son exposition runtime sans changer son `reviewStatus`.

## Provenance et licence

Chaque règle exécutable DOIT référencer une ou plusieurs preuves structurées :

- type de source ;
- titre et édition/version ;
- localisation précise, par exemple pages ou identifiant d'audit ;
- niveau d'autorité (`bookCanonical`, `bookDefault`, `bookRecommended`,
  `referenceAppDefault`, `referenceAppSuggested`, `compatible` ou
  `userCustom`) ;
- date et méthode de vérification ;
- relecteur ou décision de revue ;
- `reviewStatus` ;
- statut d'implémentation et statut d'exécution, sur leurs axes dédiés ;
- statut de licence et restrictions de redistribution.

Une observation black-box peut justifier une ergonomie, une capacité ou un
default de référence. Elle ne remplace pas une prescription métier du livre.
Une source sans licence compatible peut permettre une réimplémentation
indépendante du comportement observé ; elle ne permet pas de copier code,
texte long, actifs, branding ou données protégées.

Les chemins locaux, captures protégées, PDF, secrets, signatures privées et
données personnelles NE DOIVENT PAS figurer dans un snapshot publié. La
provenance publiée emploie des identifiants et localisations portables.

## Barrière d'exécution

Une définition est exécutable si et seulement si toutes les conditions suivantes
sont satisfaites :

1. cycle de vie `published` ;
2. autorité reconnue pour la surface demandée ;
3. version et identifiant stables ;
4. `reviewStatus: confirmed` pour chaque règle du graphe transitif ;
5. toutes les dépendances existent, sont compatibles et sont publiées ;
6. provenance et licence valides pour chaque règle exécutable ;
7. stratégie de compilation enregistrée avec la version attendue ;
8. capacités demandées compatibles avec la recette et le schedule ;
9. implémentation complète, exécution non bloquée et visibilité autorisée ;
10. validation structurelle et sémantique réussie ;
11. suite de tests et gates de publication réussie pour le snapshot exact.

L'échec d'une condition est bloquant. Le moteur NE DOIT PAS remplacer une
valeur inconnue, une dépendance manquante ou une option incompatible par un
default. Il retourne un problème structuré avec un chemin et un code stable.

## Verrouillage et dérivation

Une définition canonique publiée est immuable. Les éléments suivants sont au
minimum verrouillés : identité, version, règles, provenance, dépendances,
capacités, schéma d'options, defaults, statut de licence et empreinte.

Une `CycleConfiguration` sélectionne une définition et fournit uniquement des
valeurs dans les points d'extension déclarés. Une valeur modifiée hors de ces
points crée une définition dérivée `userCustom` avec :

- nouvel identifiant ;
- version propre ;
- référence `derivedFrom` vers l'identifiant, la version et l'empreinte du
  parent ;
- liste explicite des différences ;
- aucun badge canonique ;
- validation complète de sa propre structure.

Restaurer un default supprime l'override ; cela ne copie pas la valeur courante
du catalogue dans une définition utilisateur.

## Validateurs requis

### Validateur structurel

- identifiants, versions et enums valides ;
- absence de doublons ;
- références résolubles ;
- graphe de dépendances acyclique ;
- parent, variante, phase et alias cohérents ;
- schéma conditionnel total et sans branche morte ;
- champs requis présents et champs inconnus traités selon la version.

### Validateur de preuve et licence

- provenance sur chaque règle exécutable ;
- localisation non vide et portable ;
- niveau d'autorité compatible avec l'autorité revendiquée ;
- aucun default d'application classé comme prescription du livre ;
- licence vérifiée ou restriction explicite ;
- aucun contenu protégé embarqué.

### Validateur de publication

- état `published` uniquement après revue ;
- aucune dépendance `draft` ou `retired` non autorisée ;
- `reviewStatus: confirmed` et aucun statut d'implémentation ou d'exécution
  bloquant dans tout le graphe ;
- stratégie et version disponibles ;
- empreinte canonique calculable ;
- manifeste de tests lié à cette empreinte ;
- migration depuis les versions prises en charge ;
- matrice de visibilité et surface produit valides.

### Validateur de configuration

- options visibles et acceptées uniquement si la capacité les déclare ;
- bornes, pas, unités, charges et types de répétition respectés ;
- schedule, phases, rôles et Training Max complets ;
- aucune valeur magique pour AMRAP ou absence de charge ;
- supplemental et assistance compatibles avec leurs mouvements ;
- deload principal et assistance validés séparément ;
- custom clairement identifié et non présenté comme canonique.

### Validateur de snapshot et de migration

- empreinte et signature, si présente, valides ;
- identifiant/version/empreinte concordants ;
- migration déterministe et idempotente ;
- aucune perte silencieuse ;
- round-trip préservant les extensions inconnues lorsque le contrat le prévoit ;
- résultat identique après relecture et revalidation.

## Matrice de publication

| Autorité | Cycle de vie | `reviewStatus` requis | Preuve minimale | Exécutable | Nouvelle sélection | Ouverture historique | Badge produit |
|---|---|---|---|---|---|---|---|
| canonical | draft | `needsReview` ou `confirmed` | partielle admise, identifiée | non | non | diagnostic seulement | aucun |
| canonical | published | `confirmed` | complète, licence validée | oui | oui | oui | canonique |
| canonical | retired | `confirmed` | historiquement complète | seulement reproduction compatible | non | oui | retiré |
| compatible | draft | `needsReview` ou `confirmed` | compatibilité en revue | non | non | diagnostic seulement | aucun |
| compatible | published | `confirmed` | compatibilité prouvée | oui, sur sélection explicite | oui si parent compatible | oui | compatible |
| compatible | retired | `confirmed` | historiquement complète | reproduction compatible | non | oui | retiré |
| userCustom | draft | `needsReview` ou `confirmed` | auteur + structure minimale | simulation isolée seulement si explicitement autorisée | non publiée | oui par propriétaire | personnalisé |
| userCustom | published | `confirmed` | validation complète, sans revendication canonique | oui | selon portée/partage | oui | personnalisé |
| userCustom | retired | `confirmed` | historique valide | reproduction compatible | non | oui | retiré |

Un `reviewStatus` différent de `confirmed`, un statut d'implémentation ou
d'exécution bloquant, ou une licence incompatible force `Exécutable = non`,
quelle que soit la ligne.

## Snapshots, versions, empreintes et signatures

Le document canonique à empreinter est une sérialisation déterministe :

- ordre des clés canonique ;
- nombres et unités normalisés ;
- tableaux ordonnés uniquement lorsque l'ordre est métier ;
- aucune date volatile, chemin local ou métadonnée d'affichage instable ;
- algorithme d'empreinte versionné, au minimum SHA-256 ;
- champ d'empreinte exclu du contenu empreint.

L'empreinte protège l'intégrité et l'identité du snapshot ; elle n'établit pas
l'identité de l'éditeur. Une signature numérique est facultative pour les
snapshots locaux mais DOIT être vérifiée pour un canal de distribution qui la
revendique. Le manifeste indique `signatureAlgorithm`, `keyId` et version de
canonisation. Les clés privées ne résident jamais dans le dépôt ou les exports.

Une version publiée est immuable :

- correction métier ou changement de résultat : nouvelle version majeure ou
  mineure selon la politique documentée ;
- ajout purement compatible et optionnel : nouvelle version au minimum
  mineure ;
- correction de métadonnée sans effet de calcul : patch ;
- changement de canonisation/hash : nouvelle version du format, sans modifier
  rétroactivement les empreintes historiques.

## Import et export sûrs

### Export

Un export DOIT inclure :

- type et version du format ;
- identité, version et empreinte de la définition ;
- autorité et état éditorial ;
- configuration et overrides explicites ;
- dépendances nécessaires ou références portables ;
- provenance redistribuable ;
- empreinte du payload et, si applicable, signature.

Il NE DOIT PAS inclure secrets, données personnelles non demandées, chemins
locaux, références protégées ou contenu sans droit de redistribution.

### Import

L'import suit obligatoirement : parse isolé, validation de taille et version,
validation structurelle, vérification d'empreinte/signature, résolution des
dépendances, migration en mémoire, validation sémantique, simulation et rapport,
puis écriture atomique après confirmation.

Le rapport classe chaque élément en `accepted`, `migrated`, `customized`,
`rejected` ou `requiresReview`. Aucun élément invalide ou inconnu n'est ignoré.
Une recette importée qui revendique `canonical` sans signature/identité de
distribution reconnue est rétrogradée en `userCustom` ou rejetée ; elle n'est
jamais promue automatiquement.

Les protections minimales couvrent : limites de taille/profondeur/nombre
d'éléments, absence d'exécution de code, refus des URI ou chemins dangereux,
normalisation Unicode, détection des collisions d'identifiants, transaction
atomique et rollback.

## Compatibilité ascendante et historique

- Le moteur conserve les lecteurs/migrations nécessaires aux versions encore
  prises en charge.
- Une configuration historique référence toujours l'identifiant, la version et
  si possible l'empreinte de sa définition.
- Si la version exacte est disponible, elle est utilisée ; un snapshot plus
  récent ne la remplace jamais silencieusement.
- Si elle est retirée mais sûre, elle peut être rouverte et reproduite sans être
  proposée pour une nouvelle configuration.
- Si elle ne peut plus être exécutée en sécurité, le produit fournit une lecture
  et un rapport de migration ; il ne génère pas un résultat approximatif.
- Une migration destructive ou ambiguë exige une simulation, un choix explicite
  et une sauvegarde récupérable.
- Les aliases résolvent une identité historique vers une cible déclarée ; ils ne
  changent ni l'autorité ni la sémantique.

## Gates avant publication

Un snapshot ne passe à `published` que si les preuves suivantes sont liées à
son identifiant, sa version et son empreinte :

- revue provenance/licence ;
- validation structurelle, sémantique, graphe et configuration ;
- tests de définition, compilation et règles négatives ;
- tests de sérialisation, round-trip et migrations ;
- tests de visibilité : aucun lifecycle non publié, aucun
  `reviewStatus != confirmed` et aucun statut bloquant dans le produit ;
- tests d'import malveillant et de rollback ;
- tests UI, localisation et accessibilité lorsqu'il est visible ;
- builds, smoke tests et scénarios E2E obligatoires ;
- matrice d'audit mise à jour avec résultat exact des validations.

Un gate non exécuté ou échoué interdit la publication. Une dérogation ne peut
pas changer une règle `needsReview` en règle exécutable ; elle doit retirer la
règle du snapshot ou attendre la preuve.

## Contrats à tester après gel de l'API

Les tests contractuels suivants seront ajoutés lorsque l'API de validation et
de persistance sera gelée :

1. refus de publier un graphe dont un `reviewStatus` n'est pas `confirmed` ou
   dont l'implémentation ou l'exécution est bloquée ;
2. immutabilité d'une version publiée ;
3. dérivation automatique en `userCustom` lors d'un override verrouillé ;
4. impossibilité pour un custom PPL de revendiquer l'autorité canonique 5/3/1 ;
5. résolution transitive et acyclique des dépendances ;
6. empreinte déterministe et détection de toute altération ;
7. vérification de signature et rétrogradation/rejet d'un faux canonical ;
8. import en simulation sans écriture, puis transaction atomique ;
9. aucune perte silencieuse pendant migration et round-trip ;
10. ouverture d'un snapshot retired sans nouvelle sélection ;
11. absence de fallback lors d'une option ou dépendance inconnue ;
12. séparation de la visibilité par surface, notamment suppléments et contenus
    hors périmètre Cycle.

## Conséquences

Cette gouvernance autorise un produit extensible sans diluer la notion de
canonique. Elle permet des recettes personnalisées très libres, tout en rendant
leur origine visible et en empêchant leur confusion avec les prescriptions
sourcées. Elle impose en contrepartie des versions immuables, un graphe de
dépendances explicite, des migrations conservatrices et une publication liée à
des preuves de validation reproductibles.
