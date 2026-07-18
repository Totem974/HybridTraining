# Rapport final — Reprise d’une séance active

## Objectif

Permettre de reprendre une séance persistée avec le statut `started` sans
émettre une seconde commande de démarrage.

## Résultat

Le détail distingue désormais une séance planifiée d’une séance commencée. Le
bouton affiche « Reprendre » pour cette dernière et ouvre directement la séance
active, dont les séries, notes et repos proviennent du stockage restauré.

## Validation

Un test widget vérifie que la reprise n’appelle pas `startSession`. Le test de
persistance SQLite existant vérifie la restauration de l’état commencé, des
résultats, des notes et du repos après réouverture.

## Limites

Cette correction ne modifie ni les règles de génération ni le schéma SQLite.
