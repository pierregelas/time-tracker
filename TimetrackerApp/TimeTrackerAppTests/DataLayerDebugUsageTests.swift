import Foundation
import GRDB
import Testing
@testable import TimeTrackerApp

struct DataLayerDebugUsageTests {

    @Test func createCoreHierarchyWithTagsAndTimeEntry() throws {
        let dbQueue = try TestDatabase.makeInMemoryQueue()
        let categoryRepo = GRDBCategoryRepository(dbQueue: dbQueue)
        let projectRepo = GRDBProjectRepository(dbQueue: dbQueue)
        let taskRepo = GRDBTaskRepository(dbQueue: dbQueue)
        let tagRepo = GRDBTagRepository(dbQueue: dbQueue)
        let entryRepo = GRDBTimeEntryRepository(dbQueue: dbQueue)

        let token = Int64(Date().timeIntervalSince1970)
        let category = try categoryRepo.create(name: "debug-cat-\(token)", sortOrder: 0)
        #expect(category.id != nil)

        let project = try projectRepo.create(
            categoryId: try #require(category.id),
            name: "debug-proj-\(token)",
            color: "#AA22FF",
            sortOrder: 0
        )
        #expect(project.id != nil)

        let task = try taskRepo.create(
            projectId: try #require(project.id),
            parentTaskId: nil,
            name: "debug-task-\(token)",
            sortOrder: 0
        )
        let taskId = try #require(task.id)

        try tagRepo.setTagsForTask(taskId: taskId, ["SwiftUI", "focus_mode"])
        let assignedTags = try tagRepo.getTagsForTask(taskId: taskId)
        #expect(assignedTags.map(\.name).sorted() == ["focus_mode", "swiftui"])

        let start = token - 1800
        let end = token - 1200
        let created = try entryRepo.createManualEntry(taskId: taskId, startAt: start, endAt: end, note: "debug note")
        let dayEntries = try entryRepo.fetchDayEntries(dateLocal: Date(timeIntervalSince1970: TimeInterval(token)))

        #expect(created.id != nil)
        #expect(dayEntries.contains { $0.id == created.id && $0.note == "debug note" })
    }


    @Test func taskNotesAndTagsArePersistedOnCreateAndFetch() throws {
        let dbQueue = try TestDatabase.makeInMemoryQueue()
        let categoryRepo = GRDBCategoryRepository(dbQueue: dbQueue)
        let projectRepo = GRDBProjectRepository(dbQueue: dbQueue)
        let taskRepo = GRDBTaskRepository(dbQueue: dbQueue)
        let tagRepo = GRDBTagRepository(dbQueue: dbQueue)

        let category = try categoryRepo.create(name: "notes-cat", sortOrder: 0)
        let project = try projectRepo.create(
            categoryId: try #require(category.id),
            name: "notes-proj",
            color: nil,
            sortOrder: 0
        )

        let savedNote = "Préparer réunion client et points de suivi"
        let task = try taskRepo.create(
            projectId: try #require(project.id),
            parentTaskId: nil,
            name: "notes-task",
            note: savedNote,
            sortOrder: 0
        )
        let taskId = try #require(task.id)
        try tagRepo.setTagsForTask(taskId: taskId, ["Client", "Urgent"])

        let fetched = try taskRepo.listByProject(projectId: try #require(project.id), includeArchived: true)
        let fetchedTask = try #require(fetched.first { $0.id == task.id })
        let fetchedTags = try tagRepo.getTagsForTask(taskId: taskId).map(\.name).sorted()

        #expect(fetchedTask.note == savedNote)
        #expect(fetchedTags == ["client", "urgent"])
    }

    @Test func debugSeedAndResetPopulateExpectedAcceptanceData() throws {
        let dbQueue = try TestDatabase.makeInMemoryQueue()
        let service = DebugDataService(dbQueue: dbQueue)

        try service.seedAcceptanceTestData(now: Date(timeIntervalSince1970: 1_700_000_000))

        try dbQueue.read { db in
            let categories = try String.fetchAll(db, sql: "SELECT name FROM category ORDER BY sort_order")
            #expect(categories == ["Client", "Perso"])

            let projects = try String.fetchAll(db, sql: "SELECT name FROM project ORDER BY name")
            #expect(projects == ["Projet A", "Projet B"])

            let tasks = try String.fetchAll(db, sql: "SELECT name FROM task ORDER BY name")
            #expect(tasks == ["Admin", "Derush", "Montage", "Motion", "Running", "Sport", "Timeline"])

            let montageCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task_tag tt INNER JOIN tag t ON t.id = tt.tag_id WHERE t.name = 'montage'")
            let motionCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task_tag tt INNER JOIN tag t ON t.id = tt.tag_id WHERE t.name = 'motion'")
            #expect(montageCount == 3)
            #expect(motionCount == 1)

            let entryCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM time_entry")
            #expect(entryCount == 3)
        }

        try service.resetAllData()

        try dbQueue.read { db in
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM category") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM project") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM tag") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM task_tag") == 0)
            #expect(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM time_entry") == 0)
        }
    }
}
