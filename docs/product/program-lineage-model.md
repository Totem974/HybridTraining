# Modèle de lignées de programmes

Original, Beyond et Forever sont trois générations successives du même système
5/3/1. Un **concept** possède un identifiant canonique et, lorsque la preuve est
établie, une génération d’origine. Une **révision** décrit ce concept dans une
génération précise. Une origine ne désigne donc jamais automatiquement les règles
à exécuter.

Un **preset** est une composition complète et versionnée. Lui seul peut générer
un cycle. Le preset disponible `forever-original-fsl-v1` applique les révisions
`forever-original-531-v1` et `forever-first-set-last-5x5-v1`. L’origine du
concept principal reste Original, mais les règles réellement exécutées sont
portées par leurs révisions Forever. Il accepte trois ou quatre jours, quatre
étant recommandé.

Le catalogue valide ses identifiants, ses références, ses fréquences, son unique
recommandation disponible et l’association entre preset et générateur avant
toute utilisation par le stockage.

Les statuts `current`, `currentWithRestrictions`, `legacy`, `superseded` et
`unknown` décrivent la continuité dans Forever. Aucun statut actuel et aucune
origine ne sont déduits du seul nom d’un concept.

## Compatibilité

Les anciennes définitions utilisant `family` sont lues. La valeur `classic` est
un alias sérialisé de `original`. L’identifiant persistant et le schéma SQLite v1
restent inchangés.
