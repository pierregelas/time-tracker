# Roadmap

Ce document fige l’état du projet (v0.1.0) et propose une trajectoire de maintenance/évolution, afin de pouvoir reprendre le développement plus tard sans dépendre de l’historique de conversation.

## État actuel (v0.1.0)

MVP fonctionnel (macOS, SwiftUI, SQLite/GRDB) :
- Projects : CRUD hiérarchie Category → Project → Task → Sub-task, tags, notes, timer start/stop/switch
- Times : Day view, add/edit/delete entries, overlaps interdits, breaks auto, filtre tag
- Statistics : Today/Week/Month, totaux + breakdown par projet + par tag
- Settings : working hours lun→dim + break rules
- DB : migrations (schema initial + évolutions additives), tests data-layer + calculs

## Risques / points de fragilité (à surveiller)

1) Views très volumineuses (Projects/Times)
- Risque : régressions UI à chaque ajout, logique dispersée dans la vue, complexité croissante.
- Reco : découper en sous-vues + viewmodels dédiés (même minimal).

2) Data layer monolithique (repositories regroupés)
- Risque : conflits, navigation difficile, changements couplés.
- Reco : 1 fichier par repository + protocol/impl séparés.

3) Dépendances construites dans l’UI (instanciations directes)
- Risque : duplication, tests plus difficiles, refactors risqués.
- Reco : introduire un “AppContext” (container) injecté via Environment (repos/services/settings).

4) Sémantique auto-stop du timer (macOS)
- Risque : stop trop agressif si basé sur `scenePhase` (perte de focus ≠ fermeture).
- Reco : décider précisément :
  - stop seulement à la fermeture/quitter
  - ou stop dès que l’app n’est plus active
  et écrire un test dédié.

5) Seed/Reset debug
- Risque : logique debug qui gonfle, pollution si jamais activée en release.
- Reco : isoler dans un DebugService + garder en `#if DEBUG`.

## Roadmap proposée

### v0.1.1 — Stabilisation / UX
- Fix “tag filter” sur validation clavier (Entrée) dans Times
- Clarifier et stabiliser auto-stop (active vs quit) + test
- Petites améliorations UI (cohérence libellés, espacement, messages d’erreur)
- Documentation : README/DEV_SETUP à jour si besoin

### v0.2.0 — Maintenabilité
- Refactor ProjectsView / TimesView :
  - extraire sous-vues (rows, sheets, pickers)
  - introduire viewmodels (ProjectsVM, TimesVM, StatsVM)
- Refactor data layer :
  - split `Repositories.swift`
  - conventions d’injection (AppContext)
- CI (optionnel mais utile) :
  - GitHub Actions macOS : build + tests (au moins unit tests)

### v0.3.0 — Features utiles “perso”
- Export CSV (période + filtre projet/tag)
- Recherche (task/tag) dans Projects/Times
- Menubar minimal (start/stop + active task + total jour) si utile

## Log de décisions (à compléter)

- [ ] Auto-stop timer : (à trancher) fermeture uniquement / app inactive
- [ ] Export format : CSV (oui/non), champs
- [ ] Stratégie DI : AppContext via Environment / autre