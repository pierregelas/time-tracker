import Foundation
import GRDB

protocol CSVExporting {
    @discardableResult
    func export(toDirectory directoryURL: URL) throws -> Int
}

final class CSVExportService: CSVExporting {
    private let dbQueue: any DatabaseWriter

    init(dbQueue: any DatabaseWriter = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    @discardableResult
    func export(toDirectory directoryURL: URL) throws -> Int {
        let exportedAt = Date()
        let exportedAtEpoch = Int64(exportedAt.timeIntervalSince1970)
        let exportedAtUTC = CSVDateFormatter.utcString(fromEpochSeconds: exportedAtEpoch)
        let rows = try fetchRows()

        var csvLines: [String] = [CSVExportRow.headerLine]
        csvLines.reserveCapacity(rows.count + 1)
        for row in rows {
            csvLines.append(row.csvLine(nowEpochSeconds: exportedAtEpoch, exportedAtUTC: exportedAtUTC))
        }

        let csv = csvLines.joined(separator: "\n") + "\n"
        let filename = "time-tracker_export_\(CSVDateFormatter.filenameTimestamp(from: exportedAt)).csv"
        let outputURL = directoryURL.appendingPathComponent(filename)
        try csv.write(to: outputURL, atomically: true, encoding: .utf8)

        return rows.count
    }

    private func fetchRows() throws -> [CSVExportRow] {
        try dbQueue.read { db in
            try CSVExportRow.fetchAll(db, sql: """
            WITH ordered_tags AS (
              SELECT tt.task_id AS task_id, tag.name AS name
              FROM task_tag tt
              JOIN tag ON tag.id = tt.tag_id
              ORDER BY tt.task_id, tag.name
            ),
            tag_agg AS (
              SELECT task_id, group_concat(name, ';') AS tags
              FROM ordered_tags
              GROUP BY task_id
            )
            SELECT
              te.id AS time_entry_id,
              te.start_at AS start_at_epoch,
              te.end_at AS end_at_epoch,
              te.note AS time_entry_note,
              t.id AS task_id,
              t.name AS task_name,
              t.note AS task_note,
              pt.id AS parent_task_id,
              pt.name AS parent_task_name,
              p.id AS project_id,
              p.name AS project_name,
              p.color AS project_color,
              c.id AS category_id,
              c.name AS category_name,
              COALESCE(tag_agg.tags, '') AS tags
            FROM time_entry te
            JOIN task t ON t.id = te.task_id
            LEFT JOIN task pt ON pt.id = t.parent_task_id
            JOIN project p ON p.id = t.project_id
            JOIN category c ON c.id = p.category_id
            LEFT JOIN tag_agg ON tag_agg.task_id = t.id
            ORDER BY te.start_at, te.id
            """)
        }
    }
}

struct CSVExportRow: FetchableRecord, Decodable {
    static let headers: [String] = [
        "time_entry_id",
        "start_at_utc",
        "end_at_utc",
        "duration_seconds",
        "time_entry_note",
        "task_id",
        "task_name",
        "task_note",
        "parent_task_id",
        "parent_task_name",
        "project_id",
        "project_name",
        "project_color",
        "category_id",
        "category_name",
        "tags",
        "exported_at_utc"
    ]

    static let headerLine = headers.map(CSVFormatter.escape).joined(separator: ",")

    let timeEntryId: Int64
    let startAtEpoch: Int64
    let endAtEpoch: Int64?
    let timeEntryNote: String?
    let taskId: Int64
    let taskName: String
    let taskNote: String?
    let parentTaskId: Int64?
    let parentTaskName: String?
    let projectId: Int64
    let projectName: String
    let projectColor: String?
    let categoryId: Int64
    let categoryName: String
    let tags: String

    enum CodingKeys: String, CodingKey {
        case timeEntryId = "time_entry_id"
        case startAtEpoch = "start_at_epoch"
        case endAtEpoch = "end_at_epoch"
        case timeEntryNote = "time_entry_note"
        case taskId = "task_id"
        case taskName = "task_name"
        case taskNote = "task_note"
        case parentTaskId = "parent_task_id"
        case parentTaskName = "parent_task_name"
        case projectId = "project_id"
        case projectName = "project_name"
        case projectColor = "project_color"
        case categoryId = "category_id"
        case categoryName = "category_name"
        case tags
    }

    func csvLine(nowEpochSeconds: Int64, exportedAtUTC: String) -> String {
        let endEpoch = endAtEpoch ?? nowEpochSeconds
        let durationSeconds = max(0, endEpoch - startAtEpoch)

        let values: [String] = [
            String(timeEntryId),
            CSVDateFormatter.utcString(fromEpochSeconds: startAtEpoch),
            endAtEpoch.map { CSVDateFormatter.utcString(fromEpochSeconds: $0) } ?? "",
            String(durationSeconds),
            timeEntryNote ?? "",
            String(taskId),
            taskName,
            taskNote ?? "",
            parentTaskId.map(String.init) ?? "",
            parentTaskName ?? "",
            String(projectId),
            projectName,
            projectColor ?? "",
            String(categoryId),
            categoryName,
            tags,
            exportedAtUTC
        ]

        return values.map(CSVFormatter.escape).joined(separator: ",")
    }
}

enum CSVFormatter {
    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

enum CSVDateFormatter {
    private static let utcFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    static func utcString(fromEpochSeconds epoch: Int64) -> String {
        utcFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
    }

    static func filenameTimestamp(from date: Date) -> String {
        fileNameFormatter.string(from: date)
    }
}
