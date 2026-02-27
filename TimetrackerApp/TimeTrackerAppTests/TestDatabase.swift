import GRDB
@testable import TimeTrackerApp

enum TestDatabase {
    static func makeInMemoryQueue() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(path: ":memory:")
        try Migrations.makeMigrator().migrate(dbQueue)
        return dbQueue
    }
}
