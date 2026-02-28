# Time Tracker (macOS)

Application personnelle de suivi du temps, **macOS only**, développée en SwiftUI.

## Source of truth
Les spécifications produit et techniques sont dans `/docs` (**v3**) :
- `01_Cadrage_MVP.md`
- `02_Modele_Donnees.md`
- `03_Regles_Calcul.md`
- `04_UI_Parcours.md`
- `05_Acceptance_Tests.md`
- `06_Prompts_Codex.md`

## Périmètre MVP
- **Mode tracking : slots only** (`start_at` / `end_at`)
- **Timer unique en cours** (single running timer)
- **Stockage local : SQLite via GRDB** (dans le sandbox macOS)
- Fonctionnalités :
  - **Projects**
  - **Times**
  - **Statistics**
  - **Settings**
  - **Tags**
  - **Task Notes**

## Base de données & debug
- Base SQLite locale (GRDB) dans le sandbox de l’app.
- Chemin typique :
  - `~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/time-tracker.sqlite`
- Helpers debug (si disponibles dans le build courant) :
  - **Seed** : injecter des données de test
  - **Reset** : remettre la base à zéro

## Development
1. Ouvrir le projet Xcode (`.xcodeproj`).
2. Sélectionner le target/scheme de l’app.
3. Build & Run (`⌘R`).
4. Lancer les tests (`⌘U`).
