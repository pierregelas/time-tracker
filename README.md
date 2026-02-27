# Time Tracker (macOS)

Personal time tracking app (macOS, SwiftUI, SQLite/GRDB).

## Specs (source of truth)
All specifications are in `/docs` (v2).

## Repo structure
- `/docs` : product & technical specs (v2)
- `/TimeTrackerApp` : Xcode project

## MVP scope
- Hierarchy: Category → Project → Task → Sub-task
- Slots only (start/end time entries)
- Single running timer
- Auto breaks (computed, not stored)
- Working hours (Mon–Sun)
- Tags (Obsidian-like, multiple per task)

## Dev notes
- DB is local SQLite via GRDB
- Timestamps stored as UTC epoch seconds (INTEGER)