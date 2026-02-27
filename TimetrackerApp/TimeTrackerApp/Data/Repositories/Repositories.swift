import Foundation
import GRDB

protocol CategoryRepository {
    func list() throws -> [Category]
    func create(name: String, sortOrder: Int) throws -> Category
    func update(_ category: Category) throws -> Category
    func delete(id: Int64) throws
}

protocol ProjectRepository {
    func listByCategory(categoryId: Int64, includeArchived: Bool) throws -> [Project]
    func create(categoryId: Int64, name: String, color: String?, sortOrder: Int) throws -> Project
    func update(_ project: Project) throws -> Project
    func delete(id: Int64) throws
    func archive(id: Int64, isArchived: Bool) throws
}

protocol TaskRepository {
    func listByProject(projectId: Int64, includeArchived: Bool) throws -> [Task]
    func create(projectId: Int64, parentTaskId: Int64?, name: String, sortOrder: Int) throws -> Task
    func update(_ task: Task) throws -> Task
    func delete(id: Int64) throws
}

protocol TimeEntryRepository {
    func createTimerEntry(taskId: Int64, startAt: Int64) throws -> TimeEntry
    func stopRunningEntry(endAt: Int64) throws -> TimeEntry?
    func recoverRunningEntry(endAt: Int64) throws -> TimeEntry?
    func fetchDayEntries(dateLocal: Date) throws -> [TimeEntry]
    func createManualEntry(taskId: Int64, startAt: Int64, endAt: Int64, note: String?) throws -> TimeEntry
    func updateEntry(_ entry: TimeEntry) throws -> TimeEntry
    func deleteEntry(id: Int64) throws
    func fetchRunningEntry() throws -> TimeEntry?
    func existsOverlap(startAt: Int64, endAt: Int64, excludingId: Int64?) throws -> Bool
}

protocol SettingsRepository {
    func getWorkingHours() throws -> [WorkingHour]
    func setWorkingHours(_ hours: [WorkingHour]) throws
    func getBreakRules() throws -> BreakRules
    func setBreakRules(_ rules: BreakRules) throws
}

protocol TagRepository {
    func searchTags(prefix: String) throws -> [Tag]
    func ensureTagsExist(_ names: [String]) throws -> [Tag]
    func setTagsForTask(taskId: Int64, _ names: [String]) throws
    func getTagsForTask(taskId: Int64) throws -> [Tag]
    func normalizeTag(_ name: String) throws -> String
}

enum TagValidationError: Error {
    case invalidFormat(String)
}

enum RepositoryValidationError: Error {
    case overlappingTimeEntry
}

final class GRDBCategoryRepository: CategoryRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func list() throws -> [Category] {
        try dbQueue.read { db in
            try Category
                .order(Category.Columns.sortOrder, Category.Columns.name)
                .fetchAll(db)
        }
    }

    func create(name: String, sortOrder: Int = 0) throws -> Category {
        let now = Int64(Date().timeIntervalSince1970)
        var category = Category(id: nil, name: name, sortOrder: sortOrder, createdAt: now, updatedAt: now)
        try dbQueue.write { db in
            try category.insert(db)
        }
        return category
    }

    func update(_ category: Category) throws -> Category {
        var updated = category
        updated.updatedAt = Int64(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            try updated.update(db)
        }
        return updated
    }

    func delete(id: Int64) throws {
        try dbQueue.write { db in
            _ = try Category.deleteOne(db, key: id)
        }
    }
}

final class GRDBProjectRepository: ProjectRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func listByCategory(categoryId: Int64, includeArchived: Bool = false) throws -> [Project] {
        try dbQueue.read { db in
            var request = Project
                .filter(Project.Columns.categoryId == categoryId)
                .order(Project.Columns.sortOrder, Project.Columns.name)
            if !includeArchived {
                request = request.filter(Project.Columns.isArchived == false)
            }
            return try request.fetchAll(db)
        }
    }

    func create(categoryId: Int64, name: String, color: String?, sortOrder: Int = 0) throws -> Project {
        let now = Int64(Date().timeIntervalSince1970)
        var project = Project(
            id: nil,
            categoryId: categoryId,
            name: name,
            color: color,
            sortOrder: sortOrder,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        try dbQueue.write { db in
            try project.insert(db)
        }
        return project
    }

    func update(_ project: Project) throws -> Project {
        var updated = project
        updated.updatedAt = Int64(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            try updated.update(db)
        }
        return updated
    }

    func delete(id: Int64) throws {
        try dbQueue.write { db in
            _ = try Project.deleteOne(db, key: id)
        }
    }

    func archive(id: Int64, isArchived: Bool = true) throws {
        try dbQueue.write { db in
            guard var project = try Project.fetchOne(db, key: id) else { return }
            project.isArchived = isArchived
            project.updatedAt = Int64(Date().timeIntervalSince1970)
            try project.update(db)
        }
    }
}

final class GRDBTaskRepository: TaskRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func listByProject(projectId: Int64, includeArchived: Bool = false) throws -> [Task] {
        try dbQueue.read { db in
            var request = Task
                .filter(Task.Columns.projectId == projectId)
                .order(Task.Columns.parentTaskId, Task.Columns.sortOrder, Task.Columns.name)
            if !includeArchived {
                request = request.filter(Task.Columns.isArchived == false)
            }
            return try request.fetchAll(db)
        }
    }

    func create(projectId: Int64, parentTaskId: Int64?, name: String, sortOrder: Int = 0) throws -> Task {
        let now = Int64(Date().timeIntervalSince1970)
        var task = Task(
            id: nil,
            projectId: projectId,
            parentTaskId: parentTaskId,
            name: name,
            sortOrder: sortOrder,
            isArchived: false,
            createdAt: now,
            updatedAt: now
        )
        try dbQueue.write { db in
            try task.insert(db)
        }
        return task
    }

    func update(_ task: Task) throws -> Task {
        var updated = task
        updated.updatedAt = Int64(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            try updated.update(db)
        }
        return updated
    }

    func delete(id: Int64) throws {
        try dbQueue.write { db in
            _ = try Task.deleteOne(db, key: id)
        }
    }
}

final class GRDBTimeEntryRepository: TimeEntryRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func createTimerEntry(taskId: Int64, startAt: Int64) throws -> TimeEntry {
        let now = Int64(Date().timeIntervalSince1970)
        var entry = TimeEntry(
            id: nil,
            taskId: taskId,
            startAt: startAt,
            endAt: nil,
            note: nil,
            source: .timer,
            createdAt: now,
            updatedAt: now
        )
        try dbQueue.write { db in
            try entry.insert(db)
        }
        return entry
    }

    func stopRunningEntry(endAt: Int64) throws -> TimeEntry? {
        try dbQueue.write { db in
            guard var running = try TimeEntry
                .filter(TimeEntry.Columns.endAt == nil)
                .fetchOne(db) else {
                return nil
            }
            running.endAt = endAt
            running.updatedAt = Int64(Date().timeIntervalSince1970)
            try running.update(db)
            return running
        }
    }

    func recoverRunningEntry(endAt: Int64) throws -> TimeEntry? {
        try dbQueue.write { db in
            guard var running = try TimeEntry
                .filter(TimeEntry.Columns.endAt == nil)
                .fetchOne(db) else {
                return nil
            }
            running.endAt = endAt
            running.source = .recovered
            running.updatedAt = Int64(Date().timeIntervalSince1970)
            try running.update(db)
            return running
        }
    }

    func fetchDayEntries(dateLocal: Date) throws -> [TimeEntry] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dateLocal)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        let startEpoch = Int64(dayStart.timeIntervalSince1970)
        let endEpoch = Int64(dayEnd.timeIntervalSince1970)

        return try dbQueue.read { db in
            try TimeEntry
                .filter(sql: "start_at < ? AND COALESCE(end_at, ?) > ?", arguments: [endEpoch, Int64(Date().timeIntervalSince1970), startEpoch])
                .order(TimeEntry.Columns.startAt)
                .fetchAll(db)
        }
    }

    func createManualEntry(taskId: Int64, startAt: Int64, endAt: Int64, note: String?) throws -> TimeEntry {
        guard !((try existsOverlap(startAt: startAt, endAt: endAt, excludingId: nil))) else {
            throw RepositoryValidationError.overlappingTimeEntry
        }

        let now = Int64(Date().timeIntervalSince1970)
        var entry = TimeEntry(
            id: nil,
            taskId: taskId,
            startAt: startAt,
            endAt: endAt,
            note: note,
            source: .manual,
            createdAt: now,
            updatedAt: now
        )
        try dbQueue.write { db in
            try entry.insert(db)
        }
        return entry
    }

    func updateEntry(_ entry: TimeEntry) throws -> TimeEntry {
        if let endAt = entry.endAt, try existsOverlap(startAt: entry.startAt, endAt: endAt, excludingId: entry.id) {
            throw RepositoryValidationError.overlappingTimeEntry
        }

        var updated = entry
        updated.updatedAt = Int64(Date().timeIntervalSince1970)
        try dbQueue.write { db in
            try updated.update(db)
        }
        return updated
    }

    func deleteEntry(id: Int64) throws {
        try dbQueue.write { db in
            _ = try TimeEntry.deleteOne(db, key: id)
        }
    }

    func fetchRunningEntry() throws -> TimeEntry? {
        try dbQueue.read { db in
            try TimeEntry
                .filter(TimeEntry.Columns.endAt == nil)
                .fetchOne(db)
        }
    }

    func existsOverlap(startAt: Int64, endAt: Int64, excludingId: Int64? = nil) throws -> Bool {
        let now = Int64(Date().timeIntervalSince1970)
        return try dbQueue.read { db in
            let exists: Bool = try Bool.fetchOne(
                db,
                sql: """
                SELECT EXISTS (
                    SELECT 1
                    FROM time_entry
                    WHERE (? IS NULL OR id != ?)
                      AND ? < COALESCE(end_at, ?)
                      AND ? > start_at
                )
                """,
                arguments: [excludingId, excludingId, startAt, now, endAt]
            ) ?? false
            return exists
        }
    }
}

final class GRDBSettingsRepository: SettingsRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func getWorkingHours() throws -> [WorkingHour] {
        try dbQueue.read { db in
            try WorkingHour.order(WorkingHour.Columns.weekday).fetchAll(db)
        }
    }

    func setWorkingHours(_ hours: [WorkingHour]) throws {
        try dbQueue.write { db in
            for hour in hours where (1...7).contains(hour.weekday) {
                try db.execute(
                    sql: """
                    INSERT INTO working_hours (weekday, minutes_target)
                    VALUES (?, ?)
                    ON CONFLICT(weekday) DO UPDATE SET minutes_target = excluded.minutes_target
                    """,
                    arguments: [hour.weekday, hour.minutesTarget]
                )
            }
        }
    }

    func getBreakRules() throws -> BreakRules {
        try dbQueue.read { db in
            try BreakRules.fetchOne(db, key: 1) ?? BreakRules(minGapMinutes: 5, maxGapMinutes: 240)
        }
    }

    func setBreakRules(_ rules: BreakRules) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO break_rules (id, min_gap_minutes, max_gap_minutes)
                VALUES (1, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  min_gap_minutes = excluded.min_gap_minutes,
                  max_gap_minutes = excluded.max_gap_minutes
                """,
                arguments: [rules.minGapMinutes, rules.maxGapMinutes]
            )
        }
    }
}

final class GRDBTagRepository: TagRepository {
    private let dbQueue: DatabaseQueue
    private let validationRegex = try! NSRegularExpression(pattern: "^[A-Za-z0-9_-]+$")

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func searchTags(prefix: String) throws -> [Tag] {
        let normalized = prefix.isEmpty ? "" : try normalizeTag(prefix)
        return try dbQueue.read { db in
            try Tag
                .filter(sql: "name LIKE ?", arguments: ["\(normalized)%"])
                .order(Tag.Columns.name)
                .fetchAll(db)
        }
    }

    func ensureTagsExist(_ names: [String]) throws -> [Tag] {
        let uniqueNames = try Array(Set(names.map { try normalizeTag($0) })).sorted()
        let now = Int64(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            for name in uniqueNames {
                try db.execute(
                    sql: """
                    INSERT INTO tag (name, created_at, updated_at)
                    VALUES (?, ?, ?)
                    ON CONFLICT(name) DO UPDATE SET updated_at = excluded.updated_at
                    """,
                    arguments: [name, now, now]
                )
            }
        }

        return try dbQueue.read { db in
            guard !uniqueNames.isEmpty else { return [] }
            let placeholders = Array(repeating: "?", count: uniqueNames.count).joined(separator: ",")
            let sql = "SELECT * FROM tag WHERE name IN (\(placeholders)) ORDER BY name"
            return try Tag.fetchAll(db, sql: sql, arguments: StatementArguments(uniqueNames))
        }
    }

    func setTagsForTask(taskId: Int64, _ names: [String]) throws {
        let tags = try ensureTagsExist(names)
        let now = Int64(Date().timeIntervalSince1970)

        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM task_tag WHERE task_id = ?", arguments: [taskId])
            for tag in tags {
                guard let tagId = tag.id else { continue }
                try db.execute(
                    sql: "INSERT OR IGNORE INTO task_tag (task_id, tag_id, created_at) VALUES (?, ?, ?)",
                    arguments: [taskId, tagId, now]
                )
            }
        }
    }

    func getTagsForTask(taskId: Int64) throws -> [Tag] {
        try dbQueue.read { db in
            try Tag.fetchAll(
                db,
                sql: """
                SELECT t.*
                FROM tag t
                INNER JOIN task_tag tt ON tt.tag_id = t.id
                WHERE tt.task_id = ?
                ORDER BY t.name
                """,
                arguments: [taskId]
            )
        }
    }

    func normalizeTag(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        guard !trimmed.isEmpty,
              validationRegex.firstMatch(in: trimmed, options: [], range: range) != nil else {
            throw TagValidationError.invalidFormat(name)
        }
        return trimmed
    }
}
