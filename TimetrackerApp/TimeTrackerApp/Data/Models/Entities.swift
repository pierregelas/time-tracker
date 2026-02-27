import Foundation
import GRDB

struct Category: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "category"

    var id: Int64?
    var name: String
    var sortOrder: Int
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct Project: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "project"

    var id: Int64?
    var categoryId: Int64
    var name: String
    var color: String?
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case color
        case sortOrder = "sort_order"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name, color
        case categoryId = "category_id"
        case sortOrder = "sort_order"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct Task: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "task"

    var id: Int64?
    var projectId: Int64
    var parentTaskId: Int64?
    var name: String
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case parentTaskId = "parent_task_id"
        case name
        case sortOrder = "sort_order"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name
        case projectId = "project_id"
        case parentTaskId = "parent_task_id"
        case sortOrder = "sort_order"
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

enum TimeEntrySource: String, Codable {
    case timer
    case manual
    case recovered
}

struct TimeEntry: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "time_entry"

    var id: Int64?
    var taskId: Int64
    var startAt: Int64
    var endAt: Int64?
    var note: String?
    var source: TimeEntrySource
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case note
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, note, source
        case taskId = "task_id"
        case startAt = "start_at"
        case endAt = "end_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct WorkingHour: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "working_hours"

    var weekday: Int
    var minutesTarget: Int

    enum CodingKeys: String, CodingKey {
        case weekday
        case minutesTarget = "minutes_target"
    }

    enum Columns: String, ColumnExpression {
        case weekday
        case minutesTarget = "minutes_target"
    }
}

struct BreakRules: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "break_rules"

    var id: Int = 1
    var minGapMinutes: Int
    var maxGapMinutes: Int

    enum CodingKeys: String, CodingKey {
        case id
        case minGapMinutes = "min_gap_minutes"
        case maxGapMinutes = "max_gap_minutes"
    }

    enum Columns: String, ColumnExpression {
        case id
        case minGapMinutes = "min_gap_minutes"
        case maxGapMinutes = "max_gap_minutes"
    }
}

struct Tag: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "tag"

    var id: Int64?
    var name: String
    var createdAt: Int64
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct TaskTag: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let databaseTableName = "task_tag"

    var taskId: Int64
    var tagId: Int64
    var createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case tagId = "tag_id"
        case createdAt = "created_at"
    }

    enum Columns: String, ColumnExpression {
        case taskId = "task_id"
        case tagId = "tag_id"
        case createdAt = "created_at"
    }
}
