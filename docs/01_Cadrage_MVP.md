---
version: 3
---
### 1\. Contexte

- Application personnelle de time tracking inspirée de Tyme.
- Usage **exclusivement personnel**, **offline**, sans abonnement.
- Plateforme : **macOS only**.

### 2\. Objectif principal

Permettre de :

- créer une hiérarchie **Catégorie → Projet → Tâche → Sous-tâche**,
- lancer/arrêter un **timer unique** sur une (sous-)tâche,
- consulter/éditer les **entrées de temps**,
- calculer automatiquement les **pauses (breaks)** et le **bilan vs heures attendues**.

### 3\. Contraintes & décisions figées

- **Mode tracking : Slots uniquement** (chaque session = une entrée avec start/end).
- **Un seul timer à la fois**.
- **Breaks automatiques** à partir des trous entre entrées.
- **Pas de notion billable** (ignorée).
- **Stockage local : SQLite**.
- Pas de sync cloud / pas de compte / pas de multi-device (MVP).
- Tags **dynamiques** (liés à la tâche) : changer les tags d’une tâche **recatégorise l’historique**.

### 4\. Périmètre fonctionnel (MVP)

#### MUST (obligatoire)

**Données / organisation**

- CRUD : catégories, projets, tâches, sous-tâches.
- Déplacement simple : changer le parent (ex : tâche → autre projet) si faisable sans casse.

**Notes (Task/Sub-task)**

- Une tâche/sous-tâche peut avoir une **note** (texte libre, multiligne).
- La note est **persistante** et éditable depuis l’écran d’édition de la tâche/sous-tâche.

**Time tracking**

- Start/stop timer sur tâche ou sous-tâche.
- Si un timer tourne et qu’on démarre un autre : **stop automatique** du précédent puis start du nouveau.
- Création automatique d’une **TimeEntry** (start/end + durée calculée).

**Times (journal)**

- Vue **Day** + navigation date.
- Liste des TimeEntries du jour, triées.
- Ajout manuel d’une entrée (start/end) + édition + suppression.
- Affichage des **breaks** (gaps) comme éléments distincts.

**Working hours & bilan**

- Paramétrage des heures attendues **lun→dim (7 jours)** (template complet, valeurs initiales à 0:00).
- Calcul : total travaillé / target / overtime(+) ou undertime(–) sur une période (au minimum semaine).

**Settings minimum**

- Working hours (par jour)
- Breaks : seuil min/max (voir règles dans doc 03)
- First day of week

**Tags (transversal)**

- Une tâche/sous-tâche peut avoir **0..N tags**
- Tags au format **`[A-Za-z0-9_-]+`** (pas d’espaces, pas de caractères spéciaux)
- **Recherche/filtre** par tag (au minimum dans Statistics, idéalement aussi Projects/Times)
- **Stats par tag** sur une période (ex : semaine)

#### SHOULD (si simple à ajouter, sinon post-MVP)

- Vue **Week** dans Times.
- Recherche simple (par nom de tâche/projet).
- Stats minimales : total par projet/catégorie sur une période.

#### WON’T (hors MVP)

- Mode Cluster
- Sync iCloud / serveur / équipes
- Plugins / import/export avancé
- Rappels, idle detection, menubar avancée
- Budgets, hourly rate, revenue
- Absences, trips, dépenses

### 5\. Parcours utilisateur clés (MVP)

1. **Créer structure**
	- Créer catégorie → projet → tâches (et sous-tâches si besoin).
2. **Tracker**
	- Démarrer une tâche → arrêter → obtenir une entrée.
	- Changer de tâche en cours → stop auto précédente + nouvelle entrée.
3. **Corriger**
	- Ajouter une entrée manuelle (si oubli) ou éditer une entrée.
4. **Lire bilan**
	- Voir total jour/semaine + écart vs working hours.
	- Visualiser breaks calculés entre les entrées.

### 6\. Critères de “Done” (MVP)

- Aucune perte de données (SQLite fiable).
- Totaux cohérents : somme des entrées = total affiché.
- Breaks cohérents : affichage fidèle aux gaps selon seuils.
- Timer unique garanti (impossible d’en avoir 2 actifs).
- Édition manuelle met à jour instantanément totaux + breaks recalculés.

### 7\. Points à décider (avant doc 02/03)

- **Valeurs par défaut**
	- Working hours : **template complet lun→dim** (valeurs initiales à 0:00 sur 7 jours, modifiables)
	- Breaks : min 5 min, max 4h (modifiables)

- **Timer à la fermeture**
	- À la fermeture de l’app : si timer actif → **auto-stop** (création/complétion de l’entrée avec `end = now`)