# Architecture Base0

## Objectifs

L'architecture doit permettre d'ajouter progressivement les programmes classiques,
Beyond et Forever sans réécrire les écrans ou la base de données. Elle reste
local-first et prépare, sans les implémenter, les comptes, la synchronisation cloud,
les intégrations santé et les activités d'endurance.

## Organisation feature-first

Chaque fonctionnalité possède uniquement les sous-dossiers dont elle a besoin :

```text
features/<feature>/
  presentation/
  domain/
  data/
```

Les concepts utilisés par plusieurs fonctionnalités vivent dans `core/` seulement
s'ils sont réellement transversaux. Les widgets sans métier vivent dans
`shared/widgets/`.

## Flux des dépendances

```text
presentation -> application/domain <- data/platform
```

- La présentation transforme les intentions utilisateur en appels applicatifs.
- Le domaine contient les valeurs, règles et résultats explicables.
- Les données implémentent les contrats de persistance et de sérialisation.
- Les services de plateforme encapsulent fichiers, notifications et horloge.
- Le bootstrap assemble les implémentations ; le domaine ne connaît pas leur
  existence.

## Domaine 5/3/1

Le moteur est un ensemble Dart pur testable sans Flutter. Une prescription de série
doit conserver :

- le Training Max source ;
- le pourcentage ou la règle appliquée ;
- la charge brute ;
- la règle d'arrondi et l'incrément ;
- la charge finale ;
- les répétitions prévues ;
- le rôle de la série, dont PR, AMRAP ou test du Training Max.

Les définitions de programmes portent un identifiant stable, une version de format,
un statut de validation et leurs références documentaires. Le générateur valide une
définition avant de produire un cycle.

L'identité sépare explicitement la famille (`forever`, `beyond`, `classic`), le
template stable, la version de définition, la clé de libellé et le statut
documentaire. Le snapshot expose cette identité ; les écrans ne reconstruisent
pas le programme actif depuis un texte. Les anciennes définitions
`forever-original-fsl-v1` sans ces métadonnées utilisent un fallback déterministe
sans changement du schéma SQLite v1.

## État et injection

L'état de chaque parcours est exposé par de petits contrôleurs testables. Les
dépendances sont assemblées au démarrage et remplacées dans les tests. Aucun
singleton métier caché ni accès direct à la base depuis un widget n'est autorisé.

## Navigation

La navigation déclarative doit représenter au minimum : onboarding, programme
actif, séance, historique et réglages. Les redirections dépendent uniquement d'un
état applicatif explicite, par exemple l'existence du profil local.

## Persistance

SQLite est la source de vérité locale. Le schéma est versionné dès la version 1 et
chaque changement fournit une migration testée. Les opérations d'import sont
transactionnelles. Les suppressions métier utilisent une politique contrôlée et
des timestamps lorsque l'historique doit rester explicable.

Les tables prévues couvrent : paramètres, profil, exercices, historique de Training
Max, salles, barres, disques, programmes, séances planifiées, séances réalisées,
séries, records et métadonnées d'import.

## Sérialisation

Le format d'export enveloppe les données :

```json
{
  "format": "hybrid-training-backup",
  "schemaVersion": 1,
  "exportedAt": "2026-07-17T00:00:00Z",
  "appVersion": "0.1.0",
  "payload": {}
}
```

La détection et la validation d'un import précèdent toute écriture. L'interface
impose une simulation avec rapport avant confirmation, puis remplace les tables
dans une transaction atomique. Un adaptateur historique ne sera implémenté
qu'après réception d'un export réel anonymisé.

## Localisation et unités

Les clés et identifiants internes restent en anglais stable ; les libellés passent
par les catalogues français et anglais. Les masses sont stockées dans une unité
canonique exacte. Conversion, affichage et arrondi sont trois opérations séparées.

## Flavors

- `dev` : `fr.totem974.hybridtraining.dev`, nom visible distinct, diagnostics plus
  détaillés et données de démonstration explicitement activables ;
- `prod` : `fr.totem974.hybridtraining`, aucun affichage de diagnostic ni secret.

Les deux flavors doivent pouvoir cohabiter sur un appareil.
