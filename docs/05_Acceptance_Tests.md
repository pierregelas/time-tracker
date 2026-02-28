---
version: 3
---
## 0) Objectif

Définir un jeu de tests “humains” (et facilement automatisables plus tard) pour valider le MVP :

- CRUD hiérarchie
- Timer (Slots, un seul)
- Times (Day) + édition manuelle + validation anti-overlap
- Breaks auto
- Working hours + bilan
- Auto-stop à la fermeture + récupération crash

---

## 1) Jeu de données de test (seed manuel)

Créer la structure suivante :

### Catégories
- **Client**
- **Perso**

### Projets
- Client → **Projet A** (couleur au choix)
- Perso → **Projet B**

### Tâches / sous-tâches
Projet A :
- **Montage**
	- sous-tâche **Derush**
	- sous-tâche **Timeline**
- **Motion**

Projet B :
- **Admin**
- **Sport**
	- sous-tâche **Running**

### Tags (seed)
- `montage` assigné à : **Montage**, **Derush**, **Timeline**
- `motion` assigné à : **Motion**

---

## 2) Tests Projects (CRUD + hiérarchie)

### P-01 Créer un projet et une tâche

**Given** l’app est ouverte sur Projects  
**When** je crée une catégorie “Test”, un projet “TestProj”, une tâche “TestTask”  
**Then** la hiérarchie apparaît correctement et reste après relance de l’app.

### P-02 Renommer

**When** je renomme “TestTask” en “TestTask2”  
**Then** le nouveau nom s’affiche partout (Projects + Times + Stats si concernés).

### P-03 Supprimer avec cascade

**Given** “TestProj” contient des tâches et des entrées de temps  
**When** je supprime “TestProj”  
**Then** les tâches et les entrées liées disparaissent (pas d’orphelins), et la DB reste cohérente.

### P-04 Sous-tâches

**When** j’ajoute une sous-tâche sous “Montage” nommée “Confo”  
**Then** elle s’affiche au bon niveau, et je peux lancer un timer dessus.

---

## 3) Tests Timer (Slots, un seul timer)

### T-01 Start/Stop crée une entrée

**Given** aucun timer actif  
**When** je démarre “Derush”, j’attends ~10s, je stop  
**Then** une TimeEntry existe pour “Derush” avec `start_at < end_at` et une durée ~10s (tolérance UI).

### T-02 Un seul timer : switch automatique

**Given** “Derush” tourne  
**When** je démarre “Timeline”  
**Then** “Derush” est stoppé automatiquement (`end_at=now`) et “Timeline” devient actif (`end_at=NULL`).

### T-03 Timer sur une tâche parent

**When** je démarre “Montage” (qui a des sous-tâches)  
**Then** le timer démarre normalement et l’entrée est rattachée à “Montage”.

---

## 4) Tests Times (Day view + édition manuelle + anti-overlap)

### D-01 Day view vide

**Given** aucune entrée sur la journée affichée  
**Then** je vois un état vide + bouton “Add entry”.

### D-02 Ajouter une entrée manuelle valide

**When** j’ajoute une entrée manuelle sur “Motion” de 09:00 à 10:30 (heure locale)  
**Then** elle apparaît dans la liste, durée = 1h30, totaux mis à jour.

### D-03 Modifier une entrée

**Given** l’entrée “Motion 09:00–10:30” existe  
**When** je la modifie à 09:15–10:45  
**Then** la liste se met à jour, totaux et breaks recalculés.

### D-04 Supprimer une entrée

**When** je supprime l’entrée “Motion …”  
**Then** elle disparaît, totaux et breaks recalculés.

### D-05 Interdire overlaps (ajout)

**Given** une entrée existe de 10:00 à 11:00  
**When** j’essaie d’ajouter une entrée de 10:30 à 11:30  
**Then** l’app refuse avec un message “Chevauchement…” et aucune entrée n’est créée.

### D-06 Interdire overlaps (édition)

**Given** deux entrées existent : 09:00–10:00 et 10:15–11:00  
**When** j’édite la première en 09:30–10:30  
**Then** l’app refuse (car overlap avec 10:15–11:00) et conserve l’ancienne valeur.

### D-07 Entrée traverse minuit (si supporté)

**When** j’ajoute une entrée 23:30–00:30  
**Then** Day view du jour 1 compte 30 min, Day view du jour 2 compte 30 min.

---

## 5) Tests Breaks automatiques

### B-01 Break détecté (dans seuil)

**Given** break\_rules min=5, max=240  
**And** entrées : 09:00–10:00 et 10:10–11:00  
**Then** un Break 10:00–10:10 apparaît (durée 10 min).

### B-02 Gap trop court ignoré

**Given** entrées : 09:00–10:00 et 10:03–11:00  
**Then** aucun Break (gap 3 min < min).

### B-03 Gap trop long ignoré

**Given** entrées : 09:00–10:00 et 16:30–17:00  
**Then** aucun Break (gap > max), la coupure est “hors journée de travail”.

### B-04 Recalcul breaks après édition

**Given** entrées : 09:00–10:00 et 10:10–11:00 (break 10 min)  
**When** j’édite la seconde entrée en 10:02–11:00  
**Then** le break disparaît (gap 2 min < min).

---

## 6) Tests Working Hours + bilan

### W-01 Target par défaut lun→dim

**Given** working\_hours existe pour 7 jours  
**Then** chaque jour a une valeur (initialement 0:00), modifiable.

### W-02 Overtime/Undertime

**Given** target du jour = 7h00  
**And** worked time = 6h00  
**Then** undertime = -1h00, missing time = 1h00.

### W-03 Target = 0 n’affiche pas de “missing”

**Given** target du jour = 0  
**Then** missing time = 0 (ou caché), delta = worked time (informative).

---
## 7) Tests Tags

- **TAG-01** Créer/assigner plusieurs tags à une tâche (ex : `montage`, `clientA`)
- **TAG-02** Validation : refuser `mon tag` (espace) et `montage!` (caractère spécial)
- **TAG-03** Stats semaine : total `montage` = somme des entrées des tâches taggées
- **TAG-04** Dynamique : enlever `montage` de `Derush` → les stats `montage` diminuent sur l’historique


___
## 8) Tests Lifecycle (auto-stop + crash recovery)

### L-01 Auto-stop à la fermeture

**Given** un timer tourne depuis >10s  
**When** je ferme l’app  
**Then** au relancement, l’entrée active n’existe plus (end\_at non NULL) et la durée est cohérente.

### L-02 Crash recovery au lancement

**Given** (simulate) une entrée en DB avec `end_at = NULL`  
**When** je lance l’app  
**Then** l’app auto-stop l’entrée (end\_at = now) et ne laisse aucun timer actif.

---

## 9) Critères de réussite MVP

- Tous les tests **P/T/D/B/W/L/TAG/NOTE** passent.
- Aucune entrée `end_at NULL` persistante après fermeture/relance.
- Breaks conformes aux seuils.
- Overlaps manuels impossibles.
- Totaux par tag cohérents (TAG-03/TAG-04).