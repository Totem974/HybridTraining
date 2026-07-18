# Audit des écarts UI — 2026-07-18

Provenance : `CURRENT_IMPLEMENTATION`, `REFERENCE_UI`, `ORIGINAL_APP_OBSERVATION`.

## Corrigé dans la stabilisation

- navigation basse utilisable depuis statistiques, profil et réglages ;
- libellés sémantiques des cinq commandes basses ;
- profil résistant aux noms longs grâce à une largeur flexible ;
- notes envoyées même lors d'un retour avant le debounce ;
- import, export, suppression et sauvegarde de TM présentent une erreur réessayable ;
- repos effacé seulement après écriture réussie ;
- chevrons supprimés des tuiles inactives ;
- Beginner Prep School non sélectionnable avant raccordement du générateur v2.

## POC_TARGET restant

- onboarding scrollable et retour Android étape par étape ;
- matrice 320×568, 360×740, 390×844, 411×891 et texte 1.0 à 2.0 ;
- isolation du timer de séance et calcul des plaques ;
- liste d'historique paresseuse sur l'accueil ;
- TalkBack, ordre de focus, annonces timer/erreur, contraste et reduced motion ;
- mesure vidéo des transitions : l'audit de l'application originale ne prouve ni durée ni easing.

Les comportements observés dans l'application originale ne constituent jamais une règle Forever.
