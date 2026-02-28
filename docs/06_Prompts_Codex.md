---
version: 3
---
### Contexte commun (à inclure au début de chaque prompt Codex)

- App **macOS only** en **SwiftUI**
- Stockage **SQLite local**
- Tracking **Slots uniquement** : chaque session = `TimeEntry(start_at, end_at)`
- **Un seul timer à la fois**
- **Breaks automatiques** calculés à l’affichage (non stockés)
- **Overlaps manuels interdits**
- Timestamps stockés en **UTC epoch seconds (INTEGER)**
- **Auto-stop** à la fermeture (si timer actif → `end_at = now`)
- **Crash recovery** au lancement (si `end_at NULL` → auto-stop à `now`)
- Les specs sont dans :
	- `01_Cadrage_MVP.md`
	- `02_Modele_Donnees.md`
	- `03_Regles_Calcul.md`
	- `04_UI_Parcours.md`
	- `05_Acceptance_Tests.md`

---

## Prompt 1 — Scaffolding projet + dépendances + structure

**Objectif :** mettre en place un squelette propre pour itérer vite.

**Demande Codex :**

1. Détecter si un projet Xcode existe déjà. Sinon, créer une app macOS SwiftUI.
2. Ajouter une lib SQLite via Swift Package Manager :
	- option recommandée : **GRDB** (simple, robuste)
3. Créer une structure de dossiers (ex) :
	- `App/`
	- `Data/` (DB, migrations, repositories)
	- `Domain/` (models, services, calculs)
	- `UI/Projects`, `UI/Times`, `UI/Statistics`, `UI/Settings`
	- `Tests/`
4. Ajouter un écran “Home” minimal avec la navigation 3 onglets/sections : Projects / Times / Statistics, + Settings accessible.

**Definition of Done :**

- Le projet build/run sur macOS.
- Navigation de base visible (même si écrans vides).
- Dépendance DB installée et compilée.

---

## Prompt 2 — Base SQLite + migrations (schéma MVP)

**Objectif :** implémenter exactement le modèle DB du doc `02_Modele_Donnees.md`.

**Demande Codex :**

1. Implémenter la création de la DB locale (dans Application Support).
2. Implémenter un système de migration (GRDB Migrator ou équivalent).
3. Créer les tables et indexes :
	- `category`, `project`, `task`, `time_entry`
	- `tag`, `task_tag`
	- `working_hours`, `break_rules`, `app_settings`
4. Appliquer les contraintes :
	- CHECK `end_at IS NULL OR end_at >= start_at`
	- trigger “un seul timer actif” (insert + update)
	- tags : `tag.name` **lowercase** + caractères autorisés uniquement
5. Seed settings :
	- `working_hours` : 7 lignes (lun=1 … dim=7) avec `minutes_target = 0`
	- `break_rules` : row id=1 avec min=5, max=240

**Definition of Done :**

- À la première ouverture, DB créée + migrations appliquées.
- Un outil minimal de debug (log) confirme que les tables existent.
- Le seed est présent.

---

## Prompt 3 — Modèles + Repositories CRUD (Category/Project/Task/TimeEntry/Settings/Tags)

**Objectif :** exposer une API simple pour l’UI.

**Demande Codex :**

1. Créer les modèles Swift (structs) mappés DB :
	- Category, Project, Task (incluant parent_task_id)
	- TimeEntry, WorkingHour, BreakRules
	- Tag, TaskTag
2. Implémenter des repositories (protocol + impl) :
	- CategoryRepository : list/create/update/delete
	- ProjectRepository : listByCategory/create/update/delete/archive
	- TaskRepository : listByProject (avec hiérarchie), create/update/delete
	- TimeEntryRepository :
		- createTimerEntry(taskId, startAt)
		- stopRunningEntry(endAt)
		- fetchDayEntries(dateLocal)
		- createManualEntry(taskId, startAt, endAt, note)
		- updateEntry(...)
		- deleteEntry(id)
		- fetchRunningEntry()
		- **existsOverlap(startAt, endAt, excludingId?)** (validation overlap globale)
	- SettingsRepository :
		- get/set working hours (7 jours)
		- get/set break rules
	- TagRepository :
		- `searchTags(prefix)` (auto-complétion)
		- `ensureTagsExist([String])` (upsert)
		- `setTagsForTask(taskId, [String])` (remplace la liste)
		- `getTagsForTask(taskId)`
		- **normaliser en lowercase** + **rejeter** si format invalide (`[A-Za-z0-9_-]+`)
3. S’assurer que les opérations DB sont thread-safe (Queue GRDB).

**Definition of Done :**

- Depuis un petit “debug view” temporaire ou tests, je peux créer/lister/supprimer catégories/projets/tâches.
- Je peux insérer une `time_entry` timer et la stopper.
- Les settings sont lisibles/modifiables.
- Les tags peuvent être créés/assignés à une task et retrouvés via repo.

---

## Prompt 4 — Règles métier : timer unique + lifecycle (auto-stop + recovery)

**Objectif :** implémenter la logique “un seul timer”, auto-stop fermeture, recovery lancement.

**Demande Codex :**

1. Créer un `TimerService` (Domain) :
- start(taskId)
- stop()
- switch(to taskId) (stop current then start)
- currentRunning (observable)
2. À l’ouverture de l’app :
- si `time_entry.end_at IS NULL` → set `end_at = now`, marquer `source = 'recovered'` (ou note)
3. À la fermeture :
- si un timer tourne → stop (end\_at = now)
4. Exposer un publisher/observable pour afficher un état “running” dans l’UI (sans menubar).

**Definition of Done :**

- Test manuel : démarrer, fermer app, relancer → aucune entrée active, end\_at rempli.
- Test manuel : simuler end\_at NULL → relance stoppe automatiquement.
- Impossible d’avoir 2 entrées actives (DB + service).

---

## Prompt 5 — Calculs : périodes, totaux, breaks auto (implémentation du doc 03)

**Objectif :** coder des fonctions pures testables.

**Demande Codex :**

1. Implémenter des helpers :
- conversion date locale ↔ intervalle UTC day `[00:00, +1j)`
- découpage d’une entry sur une période (intersection)
2. Implémenter :
- `workedSeconds(for day, entries)`
- `targetSeconds(for day, workingHours)`
- `deltaSeconds`, `missingSeconds`
3. Implémenter `computeBreaks(for day, entries, breakRules)` :
- projection sur journée
- tri + fusion des intervalles
- gaps min/max → breaks list
4. Ajouter des **unit tests** (sans UI) sur :
- breaks min/max
- cas sans entries
- entry qui traverse minuit

**Definition of Done :**

- Tests unitaires verts.
- Les fonctions ne dépendent pas de SwiftUI.

---

## Prompt 6 — UI Projects (CRUD + start/stop + tags)

**Objectif :** construire l’écran Projects complet MVP.

**Demande Codex :**

1. Afficher la hiérarchie pliable :  
	Category → Project → Task → Sub-task
2. Actions CRUD :
	- add/edit/delete category
	- add/edit/delete project (inclure couleur simple)
	- add/edit/delete task + sub-task (parent_task_id)
3. Tags :
	- dans edit task/sub-task : champ tags (chips multi) + auto-complétion
	- validation `[A-Za-z0-9_-]+`, normalisation lowercase
4. Boutons start/stop sur task et sub-task :
	- si start sur B alors A tourne → switch (stop A then start B)
5. Indicateur visuel de la ligne active (running).

**Definition of Done :**

- Je peux créer la structure de test de `05_Acceptance_Tests.md` (incluant tags).
- Le timer démarre/stoppe/switch correctement depuis Projects.

---

## Prompt 7 — UI Times (Day view + add/edit/delete + anti-overlap + filtre tag)

**Objectif :** écran Times conforme MVP.

**Demande Codex :**

1. Day view :
	- navigation prev/next/today
	- header : worked/target/delta/missing
2. Filtre :
	- filtre **Tag** (dropdown/champ avec auto-complétion)
	- si tag sélectionné : n’afficher que les entrées dont la task possède ce tag
3. Liste chronologique :
	- work entries + breaks intercalés
4. Add manual entry :
	- picker task/sub-task
	- start/end local + note
	- validation : `end > start` + **anti-overlap global**
		- refuser si l’intervalle intersecte **n’importe quelle autre entrée** en DB (pas seulement “du jour”)
5. Edit entry :
	- mêmes validations (inclure overlap global en excluant l’entrée elle-même)
6. Delete entry
7. Recalcul immédiat totaux + breaks après chaque modification (et après changement de filtre tag).

**Definition of Done :**

- Tests D-01 à D-07 et B-01 à B-04 passent en manuel.
- Overlaps impossibles via UI (validation globale).
- Filtre tag fonctionne et alimente les stats/affichages.

---

## Prompt 8 — UI Statistics (MVP minimal + tags)

**Objectif :** un écran stats simple mais utile.

**Demande Codex :**

1. Sélecteur période : Today / This Week / This Month (min : This Week)
2. Afficher :
	- worked / target / delta
	- liste “Total par Project” triée desc (sur période)
	- liste **“Total par Tag”** triée desc (sur période)
3. (Optionnel simple) drill-down :
	- cliquer projet → liste total par task
	- cliquer tag → liste projets/tâches contributrices

**Definition of Done :**

- Les totaux concordent avec Times.
- Totaux par tag cohérents (TAG-03/TAG-04).
- Pas de graph requis.

---

## Prompt 9 — UI Settings (Working hours + Break rules)

**Objectif :** config MVP.

**Demande Codex :**

1. Working hours :
- 7 jours (lun→dim) éditables (heures/minutes)
2. Break rules :
- min\_gap\_minutes, max\_gap\_minutes
- validation min <= max
3. Persist DB via SettingsRepository.

**Definition of Done :**

- W-01 à W-03 passent en manuel.
- Modifier settings met à jour Times/Stats immédiatement (ou après refresh).

---

## Prompt 10 — Stabilisation : seed dataset + checklist acceptance

**Objectif :** rendre l’app testable rapidement.

**Demande Codex :**

1. Ajouter une action dev “Seed Test Data” (debug-only) qui crée le dataset de `05_Acceptance_Tests.md`.
	- inclure aussi les tags : `montage` sur Montage/Derush/Timeline, `motion` sur Motion
2. Ajouter un écran debug minimal (si nécessaire) pour voir les IDs / running entry.
3. Vérifier / corriger les points qui empêchent de passer tous les tests acceptance.

**Definition of Done :**

- Tous les scénarios **P/T/D/B/W/L/TAG/NOTE** du doc passent.

---

## Prompt 11 — Notes sur tâches / sous-tâches (Task Notes)

**Objectif :** ajouter une note (texte libre) sur chaque tâche et sous-tâche.

**Demande Codex :**

1. **Migration DB (additive)** :
	- Ajouter une migration GRDB après le schéma initial :
		- `ALTER TABLE task ADD COLUMN note TEXT;`
	- La migration doit s’appliquer proprement sur une DB existante (run once).
2. **Models** :
	- Mettre à jour `Task` pour inclure `note: String?` (colonne `note`).
3. **Repositories** :
	- Mettre à jour `TaskRepository` (create/update) pour persister `note`.
	- S’assurer que list/fetch retournent `note`.
4. **UI (Projects)** :
	- Dans l’écran Edit Task / Edit Sub-task : champ “Notes” multiligne (TextEditor).
	- Charger la note existante et sauvegarder les modifications.
5. **Tests** :
	- Ajouter/étendre un test data-layer pour vérifier persistance et lecture de `task.note` (NOTE-01).

**Definition of Done :**

- Build OK sur macOS.
- Notes visibles/éditables sur Task et Sub-task.
- Persistance OK après relance.
- Tests NOTE-01 OK.