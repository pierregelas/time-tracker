---
version: 2
---
## 1) Navigation & structure

- 3 sections principales (sidebar / tabs) :
	1. **Projects**
	2. **Times**
	3. **Statistics**
- Accès **Settings** (fenêtre ou sheet) :
	- Working Hours
	- Break rules
	- First day of week

## 2) Écran Projects

### 2.1 Contenu

- Liste hiérarchique pliable :
	- Category
		- Project
			- Task
				- Sub-task (Task avec `parent_task_id`)
- Chaque ligne affiche :
	- nom
	- (optionnel) pastille couleur (Project)
	- total sur période choisie (au minimum “Today” ou “This Week”)

### 2.2 Actions

#### CRUD

- Category :
	- Add / Rename / Delete
- Project :
	- Add / Edit (name, category, color, archived)
	- Delete
- Task / Sub-task :
	- Add task (sous un projet)
	- Add sub-task (sous une task)
	- Rename / Delete
	- Edit (inclure **Tags**)
	- Convert task ↔ sub-task (optionnel MVP ; sinon post-MVP)

#### Tags (MVP)

- Dans **Edit Task / Edit Sub-task** :
	- Champ **Tags** (multi) en “chips”
	- Auto-complétion depuis les tags existants
	- Validation : refuser si le tag ne respecte pas `[A-Za-z0-9_-]+` (message clair)

#### Time tracking (Slots, 1 timer)

- Bouton **Start/Stop** sur Task et Sub-task.
- États :
	- **idle** : aucun timer actif
	- **running** : une task/sub-task active (affichage “running”)
- Règle :
	- Start sur une task B alors que task A tourne :
		1. stop A (end_at = now)
		2. create time_entry pour B (start_at = now, end_at = NULL)

### 2.3 Feedback utilisateur (MVP)

- Indiquer clairement la ligne active (highlight + icône).
- Afficher le temps qui s’incrémente (optionnel MVP).
- En cas d’erreur DB (rare) : toast / alert “Impossible de démarrer le timer”.

## 3) Écran Times (journal)

### 3.1 Modes & période

- MVP : **Day view** (obligatoire)
- Navigation :
	- précédent / suivant
	- “Today”
- Header affiche :
	- total worked du jour
	- target du jour
	- delta (overtime/undertime)
	- missing time (si target > 0)

### 3.2 Liste des items

Liste chronologique triée par start :

- **Work entries** (TimeEntry)
	- affiche start/end (local), durée, chemin (Project > Task > Sub-task), note (si non vide)
- **Break items** (calculés)
	- affiche “Break”, start/end (optionnel), durée
- Filtre **Tag** (dropdown ou champ) pour n’afficher que les entrées dont la tâche porte ce tag.

### 3.3 Actions sur une entrée

- **Add manual entry**
	- Choisir task/sub-task
	- start/end (local)
	- note (optionnel)
- **Edit entry**
	- modifier start/end/note/task
- **Delete entry**

### 3.4 Validation (overlaps interdits)

Lors de Add/Edit :

- Refuser si `[start,end]` intersecte une autre entrée existante (hors elle-même).
- Message clair : “Chevauchement avec une autre entrée : corrige les horaires.”
- Refuser si `end <= start`.

### 3.5 États vides

- Aucun entry : afficher “No entries today” + bouton “Add entry”.
- Target > 0 : afficher “Missing time: …” (sans forcer).

### 3.6 Filtre Tag (MVP)

- Ajouter un filtre **Tag** (dropdown / champ avec auto-complétion).
- Quand un tag est sélectionné :
	- n’afficher que les **Work entries** dont la task (ou sous-tâche) possède ce tag.
	- les breaks restent affichés uniquement s’ils sont **entre** deux entrées visibles (option simple : recalcul breaks sur la liste filtrée).

## 4) Écran Statistics (MVP minimal)

### 4.1 Période

- Sélecteur simple : Today / This Week / This Month (minimum : This Week)

### 4.2 Widgets (minimum)

- Totaux période :
	- Worked time
	- Target
	- Overtime/Undertime

- Répartition :
	- Total par Project (liste triée desc)
	- **Total par Tag** (liste triée desc)

- (optionnel) Drill-down :
	- cliquer un Project → liste total par Task
	- cliquer un Tag → liste projets/tâches contributrices

## 5) Settings (MVP)

### 5.1 Working Hours (lun→dim)

- Liste 7 jours, champ minutes/heures.
- Bouton “Reset to 0” (optionnel)

### 5.2 Break rules

- min gap minutes
- max gap minutes
- Validation : min <= max

### 5.3 First day of week

- MVP : fixe Monday (ou option mais sans complexité)

## 6) Lifecycle

### 6.1 Auto-stop à la fermeture

- Si timer actif :
	- end\_at = now
	- sauvegarder en DB avant fermeture

### 6.2 Récup crash (au lancement)

- Si time\_entry avec end\_at NULL :
	- auto-stop à now
	- marquer `source='recovered'` (si utilisé)
	- (optionnel) toast “Timer recovered and stopped”