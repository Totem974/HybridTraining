# Matériaux de référence locaux

Les références sont locales, non versionnées et en lecture seule. Sur ce poste,
elles sont actuellement conservées dans :

```text
.SOURCE/
```

Ce dossier contient notamment des captures, des PDF, un XAPK, ses APK divisés et
une sortie APKTool. Il est explicitement ignoré par Git.

## Structure cible acceptée

Pour de futurs ajouts, la structure recommandée reste :

```text
reference/
  legacy-app/
    xapk/
    extracted/
  books/
  captures/
    screenshots/
    videos/
  imports/
    legacy-json/
```

`reference/` est également ignoré par Git. La migration physique de `.SOURCE/`
vers cette structure n'est pas requise pour Base0 et ne doit pas être faite sans
accord du propriétaire.

## Règles impératives

- Ne jamais commiter un PDF, XAPK, APK, fichier décompilé, certificat, capture
  personnelle, vidéo ou export JSON réel.
- Ne jamais modifier les fichiers décompilés ou les binaires historiques.
- Ne jamais copier du code décompilé dans le nouveau projet.
- Ne jamais récupérer de clé, secret, configuration Firebase, identifiant de
  facturation ou signature depuis l'ancienne application.
- Ne jamais reprendre une icône, un logo, une illustration ou une police sans
  licence confirmée.
- Conserver tout export utilisateur réel intact et hors de Git.

## Utilisation permise

Les références peuvent servir à relever les comportements observables, la
navigation, les champs, les validations, les formats de données et les règles de
calcul vérifiées indépendamment. Les livres peuvent être synthétisés sous forme de
spécifications structurées sans reproduction substantielle de leur prose.

## Éléments encore nécessaires

- un export JSON historique réel et anonymisé ;
- la confirmation des captures faisant autorité pour chaque écran ;
- la confirmation des licences de toute ressource graphique ou typographique que
  le propriétaire souhaiterait réutiliser.
