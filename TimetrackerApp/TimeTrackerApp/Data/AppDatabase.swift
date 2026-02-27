import Foundation
import GRDB

final class AppDatabase {
    static let shared: AppDatabase = {
        do { return try AppDatabase() }
        catch {
            fatalError("❌ AppDatabase init failed: \(error)")
        }
    }()

    let dbQueue: DatabaseQueue

    private init() throws {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = Bundle.main.bundleIdentifier ?? "TimeTrackerApp"
        let folder = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let dbURL = folder.appendingPathComponent("time-tracker.sqlite")

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }

        self.dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

        try Migrations.makeMigrator().migrate(dbQueue)
    }
}
