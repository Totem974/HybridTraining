# ADR-0007 — Contrat d'interface pilotée par le catalogue Cycle

- Statut : proposé
- Date : 2026-07-21
- Portée : contrat UI et futur éditeur de catalogue
- Hors portée : widgets Flutter, persistance, migrations et génération de séances

## Contexte

Le générateur Cycle doit présenter uniquement des règles revues, compatibles et
exécutables. Une interface codée autour de listes de templates, de variantes ou
d'options figées dérive inévitablement du catalogue et rend difficile l'ajout de
nouveaux livres et programmes.

L'application de référence et les captures locales servent d'inspiration
fonctionnelle pour la progression du formulaire, la découverte des variantes et
la densité d'information. Leur design, leurs textes longs, leurs actifs, leur
branding et leur structure de code ne sont pas copiés.

Le domaine possède déjà des identifiants stables (`StableCycleId`), des preuves
typées, des définitions de cycle et des schémas d'options conditionnels. Ce
contrat décrit la projection nécessaire à l'interface, sans déplacer les règles
métier dans les widgets.

## Décision

L'interface Cycle est une projection en lecture du catalogue publié et un
éditeur de `CycleConfiguration`. Elle ne connaît aucune liste métier codée en
dur. Le domaine ou l'application lui fournit un `CycleEditorViewModel` complet,
localisé et déjà filtré selon les capacités exécutables.

Le parcours logique est :

1. Template
2. Variante
3. Options
4. Schedule
5. Assistance et conditioning
6. Poids
7. Équipement
8. Résumé et génération

L'ordre visuel peut être adapté à la taille d'écran, mais les dépendances et la
sémantique restent identiques. Une sélection amont invalide est explicitement
signalée ; elle n'est jamais remplacée silencieusement par une valeur compatible.

## Identité et version

Toute ressource adressable utilise un identifiant stable, non localisé et
indépendant du stockage :

- `bookId` et `sourceId` ;
- `templateId`, `variantId` et `moduleId` ;
- `parameterId`, `scheduleId` et `sessionRoleId` ;
- `assistancePlanId`, `assistanceSlotId` et `exerciseId` ;
- `conditioningId`, `equipmentId` et `weightProfileId` ;
- `catalogReleaseId` et `definitionRevision`.

Les noms définitifs publiés par le domaine, le générateur et la persistance ont
autorité. Jusqu'à leur publication, l'UI conserve ces références comme types
opaques et n'invente ni conversion ni identifiant parallèle. Les identifiants
historiques sont conservés dans un espace d'identité distinct des identifiants
stables du domaine. Une table de correspondance versionnée peut relier un ID
historique à un ID stable lors d'une migration, sans rendre les deux
interchangeables ni réutiliser l'ancien ID comme identité métier.

Une configuration sauvegarde au minimum les IDs sélectionnés, la révision de la
définition, la version de schéma et les valeurs utilisateur. Les libellés ne sont
jamais persistés comme identité.

## Catalogue publié

Le port de lecture fournit un instantané immuable contenant uniquement :

- les entrées publiées et exécutables pour l'utilisateur courant ;
- les relations template→variantes→modules→schedules ;
- les capacités et incompatibilités structurées ;
- les schémas de paramètres ;
- les références localisées nécessaires à l'affichage ;
- la révision et l'empreinte de publication.

Les éléments dont `reviewStatus` vaut `needsReview` ou `rejected`, les éléments
documentaires et ceux dont le lifecycle n'est pas `published` ne sont pas
proposés dans le générateur. L'éditeur administratif peut les afficher avec
leurs statuts, sans leur donner un aperçu exécutable tant que la validation
métier n'aboutit pas.

## Schéma de paramètres

Chaque champ provient d'un `ParameterSchema` projetant les concepts du
`CycleOptionDefinition` existant. Il contient au minimum :

- ID, type de valeur et rôle sémantique ;
- libellé, aide courte, unité et format localisés ;
- valeur initiale sourcée et provenance de cette valeur ;
- bornes inclusives, pas et précision ;
- valeurs autorisées stables et localisées ;
- portée : globale, par lift, par rôle de séance ou par slot ;
- règles `visibleWhen`, `enabledWhen` et `requiredWhen` ;
- valeurs autorisées conditionnelles ;
- erreurs de champ et contraintes croisées identifiées.

Types minimaux : booléen, enum, entier borné, pourcentage, plage numérique,
valeur commune ou par lift, Training Max secondaire, exercice et prescription.
Une plateforme sans composant spécialisé rend un contrôle générique fidèle au
type ; elle ne convertit pas la valeur en chaîne libre.

## Compatibilité, visibilité et recalcul

Les expressions conditionnelles forment un langage fermé et sérialisable :
`always`, `present`, `equals`, `not`, `all` et `any`. Leur évaluation appartient
au domaine/application, pas à Flutter.

Après chaque intention utilisateur, le port retourne un nouvel état atomique :

- champs visibles, activés et obligatoires ;
- valeurs autorisées effectives ;
- sélections devenues incompatibles ;
- erreurs de validation et actions possibles ;
- résumé recalculé.

Une valeur masquée n'est pas implicitement supprimée. Le domaine indique si elle
reste dormante, doit être retirée avec confirmation, ou bloque la génération.
Une option non sourcée ne peut pas être rendue visible par une règle UI locale.

## View-model attendu

Le contrat conceptuel est indépendant de Flutter :

```text
CycleEditorViewModel
  catalogRelease
  locale
  steps[] { id, title, state, issues[] }
  templates[] / variants[]
  parameterGroups[] { id, role, fields[] }
  schedules[] / assistance / conditioning
  weightInputs[] / equipmentInputs[]
  summary
  canGenerate
  blockingIssues[]
  revisionToken
```

Chaque élément sélectionnable expose `id`, texte localisé, disponibilité,
raison d'indisponibilité localisée et métadonnées d'accessibilité. La provenance
brute et les IDs techniques restent cachés dans le parcours standard ; un écran
d'administration ou de diagnostic peut les afficher.

Le résumé est une projection métier structurée, jamais une phrase reconstruite
par le widget. Il couvre le template, la variante, les options, les jours réels,
les rôles et mouvements, le deload, l'assistance, le conditioning, les poids et
l'équipement.

## Port applicatif

Le futur port offre des opérations équivalentes à :

```text
loadDraft(configuration?, locale) -> CycleEditorViewModel
dispatch(EditorIntent, revisionToken) -> CycleEditorViewModel
validateForGeneration(revisionToken) -> ValidationReport
generate(revisionToken) -> GeneratedCycleReference
```

Les intentions sont typées : sélectionner un ID, définir ou retirer une valeur,
changer les jours réels, configurer un slot d'assistance, appliquer un profil de
poids ou d'équipement, confirmer une invalidation. Les commandes utilisent un
`revisionToken` pour empêcher qu'une réponse tardive écrase un état récent.

Le port ne renvoie pas d'entités SQLite et n'accepte pas de JSON métier libre.
Le générateur reçoit uniquement une `CycleConfiguration` validée par le domaine.

## Futur éditeur administratif

L'éditeur permet d'ajouter ou modifier, selon les permissions : livre/source,
template, variante, module, exercice, prescription, schedule, assistance,
conditioning, poids et équipement.

### Canonique et personnalisé

- Une définition canonique publiée est immuable.
- `clone canonical → custom` crée une nouvelle identité, conserve un lien
  `derivedFrom` vers l'ID et la révision source et copie les valeurs éditables.
- Une personnalisation ne modifie jamais silencieusement le canonique.
- Un clone ne peut pas revendiquer une provenance `bookCanonical` pour ses
  modifications utilisateur.
- La suppression d'un clone référencé est interdite ou convertie en état
  `retired`.

L'autorité et la revue sont deux axes indépendants :

- `authority` : `canonical`, `compatible` ou `userCustom` ;
- `reviewStatus` : `needsReview`, `confirmed` ou `rejected`.

`compatible` ne signifie donc pas automatiquement confirmé, et `userCustom` ne
permet pas de contourner la revue lorsqu'une définition doit être publiée ou
exécutée dans le produit.

### Cycle de vie

Le lifecycle utilise exclusivement `draft`, `inReview`, `approved`,
`published`, `retired` et `rejected`. L'ancien état `archived` est migré vers
`retired`.

`superseded` n'est pas un état : c'est une relation explicite entre une ancienne
révision et sa remplaçante. Une définition remplacée peut être `retired`, tout en
conservant son identité, son historique et la relation de succession.

Un `reviewStatus: needsReview` est un blocage métier, pas un simple badge.

La publication exige :

- schéma et relations valides ;
- IDs uniques et stables ;
- provenance et statut de revue pour chaque règle exécutable ;
- aucune référence pendante ;
- compatibilités satisfaisables ;
- migration ou justification explicite des configurations affectées ;
- tests contractuels et de génération associés ;
- numéro de révision supérieur et journal de changement.

La publication est atomique et produit un instantané immutable. Un échec ne rend
visible aucune partie de la nouvelle version. Le retour arrière republie une
nouvelle révision ; il ne réécrit pas l'historique.

## Accessibilité et plateformes

Le même contrat couvre mobile, Web et desktop :

- navigation clavier complète et ordre de focus logique ;
- intitulé accessible associé à chaque contrôle ;
- erreurs annoncées et reliées au champ concerné ;
- état désactivé accompagné d'une raison compréhensible ;
- cibles tactiles et contrastes suffisants ;
- aucune information portée uniquement par la couleur ;
- mise en page réactive sans modifier l'ordre sémantique ;
- conservation du brouillon lors d'un changement de fenêtre ou d'orientation.

## Tests contractuels futurs

Une même suite de fixtures fictives doit être exécutée contre les adaptateurs
mobile, Web et desktop :

1. aucune entrée non publiée, `needsReview` ou `rejected` n'est visible ;
2. un template ne propose que ses variantes compatibles ;
3. chaque type de paramètre produit et relit une valeur typée identique ;
4. visibilité, activation, obligation et valeurs conditionnelles suivent le
   résultat du port ;
5. une incompatibilité n'est jamais corrigée silencieusement ;
6. les valeurs dormantes suivent explicitement la politique fournie ;
7. schedule, assistance, conditioning, poids et équipement utilisent des IDs
   stables et survivent au round-trip ;
8. changement de locale ne change aucune identité ni valeur ;
9. état obsolète avec mauvais `revisionToken` est rejeté ;
10. résumé et possibilité de générer sont identiques sur les trois plateformes ;
11. navigation clavier, annonces d'erreur et ordre de focus respectent le
    contrat ;
12. clone canonique→custom conserve `derivedFrom` sans muter la source ;
13. publication invalide est atomiquement rejetée ;
14. configuration d'une révision antérieure produit migration, rapport ou rejet
    explicite, jamais un défaut incompatible.

Des tests de schéma vérifient en plus que tout champ affiché possède traduction,
type, ID, règle de validation et provenance lorsque la valeur initiale est une
prescription métier.

## Conséquences

Cette décision évite les listes et règles dupliquées dans les écrans, rend le
parcours cohérent entre plateformes et prépare un éditeur sans donner à l'UI le
pouvoir de publier une règle non revue. Elle impose en contrepartie un port de
projection riche, un langage conditionnel versionné et une coordination stricte
des IDs avec le catalogue, la persistance et le générateur.

## Points à résoudre avant implémentation

- noms canoniques définitifs des IDs publiés par les contrats DB/générateur ;
- politique exacte de conservation des valeurs devenues invisibles ;
- droits et séparation des rôles auteur, relecteur et publieur ;
- format de sérialisation du langage conditionnel ;
- granularité des versions entre catalogue complet et définition individuelle ;
- place précise du conditioning si le domaine le sépare de l'assistance.
