# Setup développement local

## Prérequis
- macOS
- Xcode (version compatible projet)

## Installation
1. Cloner le repository.
2. Ouvrir le projet Xcode (`.xcodeproj`).
3. Vérifier la résolution des dépendances Swift Package (incluant **GRDB**).
4. Build & Run (`⌘R`).

## Emplacement de la base SQLite (sandbox)
Chemin typique :

`~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/time-tracker.sqlite`

## Helpers debug
Si exposés dans le build courant :
- **Seed** : injecter un dataset de test
- **Reset** : nettoyer/réinitialiser la base

## Dépannage rapide
- **Échec build** :
  - nettoyer le build folder,
  - vérifier le target/scheme,
  - relancer la résolution des packages.
- **Échec tests (`⌘U`)** :
  - relancer après clean build,
  - vérifier la configuration locale et l’état de la DB de test.
