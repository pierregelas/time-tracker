---
version: 3
---
## 1) Conventions

- Base locale : **SQLite**.
- Stockage du temps : timestamps **UTC** en **epoch seconds** (`INTEGER`), conversion en local uniquement à l’affichage.
- Les **breaks** sont **calculés** à partir des gaps entre entrées (pas stockés en table pour le MVP).
- Hiérarchie :
	- `Category` 1→N `Project`
	- `Project` 1→N `Task`
	- `Task` peut avoir `parent_task_id` (pour sous-tâche, profondeur 1 souhaitée)
- Tags :
	- Relation **N–N** : `tag` + table de liaison `task_tag`
	- Tags **case-insensitive côté UI**, mais **normalisés et stockés en lowercase** en DB (l’app doit lowercaser avant insert/update)
	- Format tag (type Obsidian simplifié) : **`[a-z0-9_-]+`** (pas d’espaces, pas de caractères spéciaux)**

## 2) Entités

### Category

- `id` (PK)
- `name`
- `sort_order`
- `created_at`, `updated_at`

### Project

- `id` (PK)
- `category_id` (FK)
- `name`
- `color` (ex: hex string) — MVP: purement visuel
- `sort_order`
- `is_archived`
- `created_at`, `updated_at`

### Task (inclut sous-tâches)

- `id` (PK)
- `project_id` (FK)
- `parent_task_id` (FK nullable vers `task.id`)
	- `NULL` = tâche
	- non-NULL = sous-tâche
- `name`
- `note` (TEXT nullable) — note de tâche (texte libre)
- `sort_order`
- `is_archived`
- `created_at`, `updated_at`

### TimeEntry (Slots)

- `id` (PK)
- `task_id` (FK)
- `start_at` (epoch seconds, UTC)
- `end_at` (epoch seconds, UTC, nullable si timer en cours)
- `note` (TEXT nullable)
- `source` (TEXT : `timer` | `manual`) — utile pour debug
- `created_at`, `updated_at`

### Tag
- `id` (PK)
- `name` (TEXT, unique, lowercase recommandé)
- `created_at`, `updated_at`

### TaskTag (relation)

- `task_id` (FK)
    
- `tag_id` (FK)
    
- PK composite `(task_id, tag_id)`

### Settings (MVP)

#### Working hours (par jour)

Table normalisée (plutôt que 7 colonnes) :

- `working_hours`
	- `weekday` (INTEGER 1..7, 1=lundi)
	- `minutes_target` (INTEGER >=0)

#### Break rules

- `break_rules`
	- `min_gap_minutes` (INTEGER >=0) ex: 5
	- `max_gap_minutes` (INTEGER >=0) ex: 240

#### App settings divers

- `app_settings`
	- `key` (TEXT PK)
	- `value` (TEXT)

## 3) Contraintes métier au niveau DB (MVP)

- **Un seul timer actif** : une seule `time_entry` avec `end_at IS NULL`.
- Cohérence d’une entrée : `end_at` doit être `NULL` ou `>= start_at`.
- Sous-tâche : si `parent_task_id` est défini, idéalement :
	- parent dans le **même project**
	- profondeur maximale 1 (parent ne doit pas être lui-même une sous-tâche)

(La DB peut faire respecter ces règles via triggers ; sinon, au minimum via logique app + assertions.)

## 4) Schéma SQLite (SQL de référence)



```SQL
PRAGMA foreign_keys = ON;  
  
-- CATEGORY  
CREATE TABLE IF NOT EXISTS category (  
id INTEGER PRIMARY KEY,  
name TEXT NOT NULL,  
sort_order INTEGER NOT NULL DEFAULT 0,  
created_at INTEGER NOT NULL,  
updated_at INTEGER NOT NULL  
);  
  
-- PROJECT  
CREATE TABLE IF NOT EXISTS project (  
id INTEGER PRIMARY KEY,  
category_id INTEGER NOT NULL,  
name TEXT NOT NULL,  
color TEXT,  
sort_order INTEGER NOT NULL DEFAULT 0,  
is_archived INTEGER NOT NULL DEFAULT 0,  
created_at INTEGER NOT NULL,  
updated_at INTEGER NOT NULL,  
FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE  
);  
  
-- TASK (incl. sub-tasks)  
CREATE TABLE IF NOT EXISTS task (  
id INTEGER PRIMARY KEY,  
project_id INTEGER NOT NULL,  
parent_task_id INTEGER,  
name TEXT NOT NULL,  
note TEXT,  
sort_order INTEGER NOT NULL DEFAULT 0,  
is_archived INTEGER NOT NULL DEFAULT 0,  
created_at INTEGER NOT NULL,  
updated_at INTEGER NOT NULL,  
FOREIGN KEY(project_id) REFERENCES project(id) ON DELETE CASCADE,  
FOREIGN KEY(parent_task_id) REFERENCES task(id) ON DELETE SET NULL  
);  
  
-- TIME ENTRY (slots)  
CREATE TABLE IF NOT EXISTS time_entry (  
id INTEGER PRIMARY KEY,  
task_id INTEGER NOT NULL,  
start_at INTEGER NOT NULL,  
end_at INTEGER,  
note TEXT,  
source TEXT NOT NULL DEFAULT 'timer', -- 'timer'|'manual'|'recovered'  
created_at INTEGER NOT NULL,  
updated_at INTEGER NOT NULL,  
FOREIGN KEY(task_id) REFERENCES task(id) ON DELETE CASCADE,  
CHECK (end_at IS NULL OR end_at >= start_at)  
);  
  
-- TAG  
CREATE TABLE IF NOT EXISTS tag (  
id INTEGER PRIMARY KEY,  
name TEXT NOT NULL,  
created_at INTEGER NOT NULL,  
updated_at INTEGER NOT NULL,  
CHECK (length(name) > 0),  
CHECK (name = lower(name)),  
CHECK (name NOT GLOB '*[^a-z0-9_-]*')  
);  
  
CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_name_unique  
ON tag(name);  
  
-- TASK_TAG (many-to-many)  
CREATE TABLE IF NOT EXISTS task_tag (  
task_id INTEGER NOT NULL,  
tag_id INTEGER NOT NULL,  
created_at INTEGER NOT NULL,  
PRIMARY KEY (task_id, tag_id),  
FOREIGN KEY(task_id) REFERENCES task(id) ON DELETE CASCADE,  
FOREIGN KEY(tag_id) REFERENCES tag(id) ON DELETE CASCADE  
);  
  
CREATE INDEX IF NOT EXISTS idx_task_tag_tag_id ON task_tag(tag_id);  
CREATE INDEX IF NOT EXISTS idx_task_tag_task_id ON task_tag(task_id);  
  
-- SETTINGS: working hours (Mon..Sun = 1..7)  
CREATE TABLE IF NOT EXISTS working_hours (  
weekday INTEGER PRIMARY KEY, -- 1..7  
minutes_target INTEGER NOT NULL DEFAULT 0,  
CHECK (weekday BETWEEN 1 AND 7),  
CHECK (minutes_target >= 0)  
);  
  
-- SETTINGS: break rules (single row)  
CREATE TABLE IF NOT EXISTS break_rules (  
id INTEGER PRIMARY KEY CHECK (id = 1),  
min_gap_minutes INTEGER NOT NULL DEFAULT 5,  
max_gap_minutes INTEGER NOT NULL DEFAULT 240,  
CHECK (min_gap_minutes >= 0),  
CHECK (max_gap_minutes >= 0)  
);  
  
-- SETTINGS: key/value  
CREATE TABLE IF NOT EXISTS app_settings (  
key TEXT PRIMARY KEY,  
value TEXT NOT NULL  
);  
  
-- INDEXES  
CREATE INDEX IF NOT EXISTS idx_task_project ON task(project_id);  
CREATE INDEX IF NOT EXISTS idx_task_parent ON task(parent_task_id);  
CREATE INDEX IF NOT EXISTS idx_entry_task_start ON time_entry(task_id, start_at);  
CREATE INDEX IF NOT EXISTS idx_entry_start ON time_entry(start_at);  
  
-- TRIGGER: forbid multiple running timers (end_at IS NULL)  
CREATE TRIGGER IF NOT EXISTS trg_one_running_timer  
BEFORE INSERT ON time_entry  
WHEN NEW.end_at IS NULL  
BEGIN  
SELECT  
CASE  
WHEN EXISTS (SELECT 1 FROM time_entry WHERE end_at IS NULL)  
THEN RAISE(ABORT, 'Only one running timer allowed')  
END;  
END;  
  
-- TRIGGER: optional update guard (keep the "one running" invariant)  
CREATE TRIGGER IF NOT EXISTS trg_one_running_timer_update  
BEFORE UPDATE OF end_at ON time_entry  
WHEN NEW.end_at IS NULL  
BEGIN  
SELECT  
CASE  
WHEN EXISTS (SELECT 1 FROM time_entry WHERE end_at IS NULL AND id != NEW.id)  
THEN RAISE(ABORT, 'Only one running timer allowed')  
END;  
END;

```



## 5) Notes d’implémentation (pour l’app)

- **Auto-stop à la fermeture** : l’app doit faire un `UPDATE time_entry SET end_at = now` sur l’entrée active avant de quitter.
- Cas crash : au lancement, si `end_at IS NULL`, décider une règle (ex: auto-stop à `now` et marquer `source='recovered'` ou note). (À cadrer dans doc 03 ou 05.)
- Comme tu veux du **dynamique**, on **ne met pas** de `tag_id` dans `time_entry`. Les stats par tag se font via jointure `time_entry → task → task_tag → tag`.
- **Task notes (v3)** : la colonne `task.note` est une **extension additive** (migration type `ALTER TABLE task ADD COLUMN note TEXT` pour les DB existantes).