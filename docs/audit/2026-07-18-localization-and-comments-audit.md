# Audit localisation et commentaires — 2026-07-18

## CURRENT

`AppStrings` centralise une grande partie du français et de l'anglais, mais le français est construit directement par les écrans. `MaterialApp` ne raccorde pas encore les delegates, locales supportées ou un sélecteur. La bibliothèque et le runtime composable contiennent encore des littéraux français. Les dates Material peuvent donc suivre une autre locale que le corps de l'écran.

Les quatre commentaires DartDoc existants sont utiles. Aucun commentaire généré ou périmé massif n'a été trouvé ; le besoin principal est la mise à jour des documents d'architecture.

## POC_TARGET

Migration isolée vers ARB/`gen_l10n`, avec FR/EN, pluriels, placeholders, dates/nombres/unités, erreurs et semantics. Ajouter des tests app entière en anglais et à 200 %. Les IDs persistants, enums et noms SQLite restent en anglais stable.

Statut : `VALIDATED_WITH_LIMITS`. Aucun nouveau texte produit par cette stabilisation ne doit être dispersé hors du système existant.
