import Foundation
import Testing
@testable import TimeTrackerApp

@MainActor
struct TimerServiceTests {

    @Test func startSwitchAndRecoveryLifecycle() throws {
        let dbQueue = try TestDatabase.makeInMemoryQueue()
        let categoryRepo = GRDBCategoryRepository(dbQueue: dbQueue)
        let projectRepo = GRDBProjectRepository(dbQueue: dbQueue)
        let taskRepo = GRDBTaskRepository(dbQueue: dbQueue)
        let timeEntryRepo = GRDBTimeEntryRepository(dbQueue: dbQueue)

        let category = try categoryRepo.create(name: "cat", sortOrder: 0)
        let project = try projectRepo.create(categoryId: try #require(category.id), name: "proj", color: nil, sortOrder: 0)
        let taskA = try taskRepo.create(projectId: try #require(project.id), parentTaskId: nil, name: "task-a", sortOrder: 0)
        let taskB = try taskRepo.create(projectId: try #require(project.id), parentTaskId: nil, name: "task-b", sortOrder: 1)

        let times: [Int64] = [1_700_000_000, 1_700_000_100, 1_700_000_200, 1_700_000_300]
        var index = 0
        let timerService = TimerService(
            timeEntryRepository: timeEntryRepo,
            nowProvider: {
                defer { index += 1 }
                return times[min(index, times.count - 1)]
            },
            recoverOnInit: false
        )

        try timerService.start(taskId: try #require(taskA.id))
        let firstRunning = try #require(timerService.currentRunningEntry)
        #expect(firstRunning.endAt == nil)
        #expect(firstRunning.taskId == taskA.id)

        try timerService.switch(to: try #require(taskB.id))
        let switchedRunning = try #require(timerService.currentRunningEntry)
        #expect(switchedRunning.endAt == nil)
        #expect(switchedRunning.taskId == taskB.id)

        let entriesAfterSwitch = try timeEntryRepo.fetchDayEntries(dateLocal: Date(timeIntervalSince1970: TimeInterval(times[2])))
        let firstEntry = try #require(entriesAfterSwitch.first(where: { $0.id == firstRunning.id }))
        #expect(firstEntry.endAt != nil)

        let recoverResult = try timerService.recoverIfNeeded()
        #expect(recoverResult != nil)
        #expect(timerService.currentRunningEntry == nil)

        let entriesAfterRecovery = try timeEntryRepo.fetchDayEntries(dateLocal: Date(timeIntervalSince1970: TimeInterval(times[3])))
        let recoveredEntry = try #require(entriesAfterRecovery.first(where: { $0.id == switchedRunning.id }))
        #expect(recoveredEntry.endAt != nil)
        #expect(recoveredEntry.source == .recovered)
    }

}
