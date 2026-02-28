# Migrations (GRDB)

Ce guide décrit les règles de migration de schéma SQLite pour Time Tracker.

## Règles
- **Ne jamais éditer une migration déjà sortie** (immutabilité).
- Toute évolution DB doit passer par une **migration additive**.
- Conserver la compatibilité avec les bases déjà créées.

## Procédure
1. Ajouter une nouvelle migration dans l’endroit dédié aux migrations GRDB (registre/sequence des migrations).
2. Donner un identifiant de migration unique et ordonné.
3. Limiter la migration aux changements de schéma/données strictement nécessaires.
4. Lancer l’app sur une base existante pour vérifier :
   - application de la migration sans erreur,
   - conservation des données existantes,
   - fonctionnement nominal après upgrade.
5. Vérifier qu’une base neuve reconstruit bien le schéma complet (migrations depuis zéro).

## Test sur DB existante
- Conserver une copie d’une DB d’une version précédente.
- Démarrer l’app (ou les tests) avec cette DB.
- Valider que la migration s’exécute correctement et que les écrans principaux restent opérationnels.

## Versioning documentaire
- Les specs fonctionnelles actuelles sont en **v3** (`/docs`).
- En cas d’évolution de périmètre/règles :
  - incrémenter la version documentaire (**v3 → v4**),
  - mettre à jour les documents impactés,
  - conserver une trace claire des changements (README/CHANGELOG/notes de release).
