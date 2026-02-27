import Foundation
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
}
