---
version: 2
---
### 1) Définitions

- **TimeEntry (work)** : intervalle `[start_at, end_at]` (UTC epoch seconds), lié à une task (ou sous-tâche).
- **Durée d’une entrée** : `duration = max(0, end_at - start_at)` en secondes, affichée en h:min.
- **Timer actif** : `time_entry.end_at IS NULL`. Dans les calculs d’affichage temps réel, on considère `end_at = now` (sans l’écrire en DB tant que non stoppé).

### 2) Invariants

- **Un seul timer** : au maximum 1 entrée avec `end_at IS NULL`.
- **Cohérence** : `end_at >= start_at` (sinon entrée invalide → à corriger en UI).
- **Auto-stop à la fermeture** : lors de `appWillTerminate`, si entrée active → `end_at = now` (écriture DB).

### 3) Périodes et agrégations

- **Day view** : période `[D 00:00 local, D+1 00:00 local)` convertie en UTC pour requêtes.
- **Week view** (si activée plus tard) : selon `first_day_of_week` (MVP: Monday) → `[Wstart 00:00, Wend 00:00)`.
- Toutes les stats “sur période” filtrent les entries dont l’intervalle intersecte la période.

#### 3.1 Découpage des entrées qui chevauchent une période

Pour une période `[Pstart, Pend)` :

- `effective_start = max(entry.start_at, Pstart)`
- `effective_end = min(entry.end_at_or_now, Pend)`
- Contribution = `max(0, effective_end - effective_start)`

(Important pour les entrées qui passent minuit.)

### 4) Calcul des breaks automatiques

Les breaks ne sont **pas stockés** : ils sont générés à l’affichage pour une période (au minimum par jour).

#### 4.1 Paramètres

Depuis `break_rules` :

- `min_gap_minutes` (défaut 5)
- `max_gap_minutes` (défaut 240)

On convertit en secondes : `min_gap = min_gap_minutes*60`, `max_gap = max_gap_minutes*60`.

#### 4.2 Règle de génération

Pour une journée donnée :

1. Récupérer toutes les entrées “work” dont l’intervalle intersecte la journée.
2. Les **projeter** sur la journée (cf 3.1) et obtenir une liste d’intervalles effectifs.
3. Trier par `effective_start`, puis fusionner les intervalles qui se chevauchent (pour éviter des gaps négatifs).
4. Entre deux intervalles consécutifs `A` et `B` :
	- `gap = B.start - A.end`
	- Si `gap >= min_gap` ET `gap <= max_gap` → générer un **Break** `[A.end, B.start]`.
	- Sinon → rien (gap ignoré, considéré “hors journée de travail” ou trop long).

#### 4.3 Affichage des breaks

- Un break est affiché comme une ligne “Break” avec start/end (optionnel) et durée.
- Les breaks sont intercalés dans la liste chronologique.

### 5) Working hours → target, overtime/undertime, missing time

#### 5.1 Working hours (objectif)

Table `working_hours` : `weekday (1..7)` → `minutes_target`.  
Pour une journée locale :

- `target_minutes = working_hours[weekday].minutes_target`
- `target_seconds = target_minutes * 60`

Défaut MVP : template lun→dim existant, valeurs initiales à 0.

#### 5.2 Worked time

Pour une journée :

- `worked_seconds = somme des contributions des work entries sur la journée` (cf 3.1)

#### 5.3 Overtime / undertime

- `delta_seconds = worked_seconds - target_seconds`
- si `delta_seconds > 0` → overtime
- si `delta_seconds < 0` → undertime (valeur absolue à l’affichage possible)

#### 5.4 Missing time (option affichage Times)

Dans Tyme, “missing time” correspond à un déficit vs target. MVP :

- `missing_seconds = max(0, target_seconds - worked_seconds)`
- Si target = 0 → missing = 0 (pas d’incitation à remplir).

### 6) Totaux par hiérarchie (Tasks / Projects / Categories)

Sur une période donnée :

- Total Task = somme des contributions des entries de cette task (+ sous-tâches si on veut un total “parent”, au choix UI).
- Total Project = somme des tasks du project.
- Total Category = somme des projects.

Règle MVP recommandée :

- Une **sous-tâche compte uniquement pour elle-même**, et le total “tâche parente” (si affiché) est la somme de ses sous-tâches + ses propres entries (si on autorise de timer aussi sur la tâche parente).  
	Les entrées peuvent être rattachées à une tâche même si elle a des sous-tâches.





### 8) Édition manuelle (TimeEntry)

- Ajout manuel : l’utilisateur saisit start/end (local), conversion en UTC, insertion DB.
- À chaque modification (ajout/édition/suppression) :
	- recalcul immédiat des totaux jour + breaks.

### 9) Cas limites (MVP)

- **Overlaps interdits (global)** : lors de l’ajout/édition manuelle, refuser si le nouvel intervalle intersecte **n’importe quelle autre entrée** en DB (pas seulement “dans le jour affiché”).  Règle d’intersection (en secondes, fin exclusive recommandée) : overlap si `newStart < existingEnd` ET `newEnd > existingStart`.  Si une entrée existante a `end_at NULL`, considérer `existingEnd = now` le temps de la validation.  
- **Entrée active au lancement** (crash) :  
- règle simple : auto-stop à `now` au lancement et marquer `source='recovered'` (ou ajouter une note).  
(À valider dans tests `05_Acceptance_Tests.md`.)

### 10) Tags (transversal)

- **Format & normalisation**
	- À la saisie : accepter `A-Za-z0-9_-` (sans espaces, sans caractères spéciaux), puis **normaliser en lowercase** avant sauvegarde.
	- En DB : `tag.name` est **lowercase** et unique.

- **Attribution dynamique**
	- Un `TimeEntry` hérite des tags de sa `Task` via la relation `task_tag`.
	- Changer les tags d’une tâche **recatégorise automatiquement tout l’historique** des `time_entry` liés.

- **Totaux par tag (période)**
	- Total d’un tag = somme des contributions (intersection période) de tous les `time_entry` dont la `task` est liée à ce tag.
	- **Multi-tags** : une même entrée compte **dans chaque tag** attribué à la tâche.