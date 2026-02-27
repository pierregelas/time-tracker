import Foundation
import GRDB

enum Migrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v2_initial") { db in
            // Align with SQL reference
            try db.execute(sql: "PRAGMA foreign_keys = ON;")

            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS category (
              id          INTEGER PRIMARY KEY,
              name        TEXT NOT NULL,
              sort_order  INTEGER NOT NULL DEFAULT 0,
              created_at  INTEGER NOT NULL,
              updated_at  INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS project (
              id          INTEGER PRIMARY KEY,
              category_id INTEGER NOT NULL,
              name        TEXT NOT NULL,
              color       TEXT,
              sort_order  INTEGER NOT NULL DEFAULT 0,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at  INTEGER NOT NULL,
              updated_at  INTEGER NOT NULL,
              FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS task (
              id             INTEGER PRIMARY KEY,
              project_id     INTEGER NOT NULL,
              parent_task_id INTEGER,
              name           TEXT NOT NULL,
              sort_order     INTEGER NOT NULL DEFAULT 0,
              is_archived    INTEGER NOT NULL DEFAULT 0,
              created_at     INTEGER NOT NULL,
              updated_at     INTEGER NOT NULL,
              FOREIGN KEY(project_id) REFERENCES project(id) ON DELETE CASCADE,
              FOREIGN KEY(parent_task_id) REFERENCES task(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS time_entry (
              id         INTEGER PRIMARY KEY,
              task_id    INTEGER NOT NULL,
              start_at   INTEGER NOT NULL,
              end_at     INTEGER,
              note       TEXT,
              source     TEXT NOT NULL DEFAULT 'timer',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY(task_id) REFERENCES task(id) ON DELETE CASCADE,
              CHECK (end_at IS NULL OR end_at >= start_at)
            );

            CREATE TABLE IF NOT EXISTS tag (
              id         INTEGER PRIMARY KEY,
              name       TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              CHECK (length(name) > 0),
              CHECK (name = lower(name)),
              CHECK (name NOT GLOB '*[^a-z0-9_-]*')
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_tag_name_unique
            ON tag(name);

            CREATE TABLE IF NOT EXISTS task_tag (
              task_id    INTEGER NOT NULL,
              tag_id     INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY (task_id, tag_id),
              FOREIGN KEY(task_id) REFERENCES task(id) ON DELETE CASCADE,
              FOREIGN KEY(tag_id) REFERENCES tag(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_task_tag_tag_id  ON task_tag(tag_id);
            CREATE INDEX IF NOT EXISTS idx_task_tag_task_id ON task_tag(task_id);

            CREATE TABLE IF NOT EXISTS working_hours (
              weekday        INTEGER PRIMARY KEY,
              minutes_target INTEGER NOT NULL DEFAULT 0,
              CHECK (weekday BETWEEN 1 AND 7),
              CHECK (minutes_target >= 0)
            );

            CREATE TABLE IF NOT EXISTS break_rules (
              id              INTEGER PRIMARY KEY CHECK (id = 1),
              min_gap_minutes INTEGER NOT NULL DEFAULT 5,
              max_gap_minutes INTEGER NOT NULL DEFAULT 240,
              CHECK (min_gap_minutes >= 0),
              CHECK (max_gap_minutes >= 0)
            );

            CREATE TABLE IF NOT EXISTS app_settings (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_task_project      ON task(project_id);
            CREATE INDEX IF NOT EXISTS idx_task_parent       ON task(parent_task_id);
            CREATE INDEX IF NOT EXISTS idx_entry_task_start  ON time_entry(task_id, start_at);
            CREATE INDEX IF NOT EXISTS idx_entry_start       ON time_entry(start_at);

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
            """)

            // Seed: working_hours 1..7 => 0 minutes
            for weekday in 1...7 {
                try db.execute(
                    sql: "INSERT OR IGNORE INTO working_hours (weekday, minutes_target) VALUES (?, 0);",
                    arguments: [weekday]
                )
            }

            // Seed: break_rules singleton
            try db.execute(sql: """
            INSERT OR IGNORE INTO break_rules (id, min_gap_minutes, max_gap_minutes)
            VALUES (1, 5, 240);
            """)
        }

        return migrator
    }
}