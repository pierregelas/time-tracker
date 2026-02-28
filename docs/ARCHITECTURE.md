# Architecture

Ce document résume l’architecture logique de l’application (référence : specs v3 dans `/docs`).

## 1) Vue d’ensemble des couches

### UI (SwiftUI)
- Écrans principaux : Projects, Times, Statistics.
- Settings (working hours, break rules, first day of week).
- La UI orchestre les actions utilisateur (start/stop timer, création/édition, filtres, stats).

### Domain
- **TimerService** : logique de démarrage/arrêt du timer, application des invariants métier.
- **TimeCalculations** : calculs dérivés (durées, pauses automatiques, agrégations période).
- Responsabilité : appliquer les règles métier indépendamment de la persistance.

### Data (GRDB)
- **AppDatabase** : configuration GRDB, ouverture de la base, accès DB.
- **Migrations** : évolution versionnée du schéma SQLite.
- **Models** : mapping lignes DB ↔︎ modèles Swift.
- **Repositories** : opérations CRUD / requêtes métier côté persistance.

## 2) Flux principaux

### Start/Stop timer → `time_entry`
1. Start : création d’une entrée `time_entry` avec `start_at` et `end_at = NULL`.
2. Stop : mise à jour de l’entrée active avec `end_at = now`.
3. Invariant métier : **un seul timer actif** (`end_at IS NULL`) à tout instant.

### Breaks calculés (non stockés)
- Les pauses ne sont pas persistées.
- Elles sont calculées à la volée depuis les gaps entre entrées temporelles adjacentes.

### Tags dynamiques via `task_tag`
- Les tags sont liés aux tâches via la table de liaison `task_tag`.
- Les changements de tags d’une tâche impactent l’historique agrégé (stats par tag), car l’attribution est dynamique côté requête.

## 3) Conventions
- **Timestamps** : UTC epoch seconds (`Int64`).
- **Nommage** : colonnes DB en `snake_case`, mapping Swift en `camelCase`.
- **Invariant global** : “single running timer”.
