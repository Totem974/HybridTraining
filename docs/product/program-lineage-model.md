# Modèle de lignées de programmes

Original, Beyond et Forever sont trois générations successives du même système
5/3/1. Un **concept** possède un identifiant canonique et, lorsque la preuve est
établie, une génération d’origine. Une **révision** décrit ce concept dans une
génération précise. Une origine ne désigne donc jamais automatiquement les règles
à exécuter.

Un **preset** est une composition complète et versionnée. Lui seul peut générer
un cycle. Le preset disponible `forever-original-fsl-v1` applique les règles
Forever, le travail principal Original 5/3/1 et la révision Forever de First Set
Last 5 × 5. Il accepte trois ou quatre jours, quatre étant recommandé.

Les statuts `current`, `currentWithRestrictions`, `legacy`, `superseded` et
`unknown` décrivent la continuité dans Forever. Aucun statut actuel et aucune
origine ne sont déduits du seul nom d’un concept.

## Compatibilité

Les anciennes définitions utilisant `family` sont lues. La valeur `classic` est
un alias sérialisé de `original`. L’identifiant persistant et le schéma SQLite v1
restent inchangés.
