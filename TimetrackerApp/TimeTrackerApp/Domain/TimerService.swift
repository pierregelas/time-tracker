import Foundation
import Observation

@MainActor
@Observable
final class TimerService {
    private let timeEntryRepository: TimeEntryRepository
    private let nowProvider: () -> Int64

    private(set) var currentRunningEntry: TimeEntry?

    init(
        timeEntryRepository: TimeEntryRepository = GRDBTimeEntryRepository(),
        nowProvider: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) },
        recoverOnInit: Bool = true
    ) {
        self.timeEntryRepository = timeEntryRepository
        self.nowProvider = nowProvider

        if recoverOnInit {
            try? recoverIfNeeded()
        } else {
            try? refreshCurrentRunningEntry()
        }
    }

    func start(taskId: Int64) throws {
        if currentRunningEntry != nil {
            _ = try stop()
        }
        _ = try timeEntryRepository.createTimerEntry(taskId: taskId, startAt: nowProvider())
        try refreshCurrentRunningEntry()
    }

    @discardableResult
    func stop() throws -> TimeEntry? {
        let stopped = try timeEntryRepository.stopRunningEntry(endAt: nowProvider())
        currentRunningEntry = nil
        return stopped
    }

    func `switch`(to taskId: Int64) throws {
        _ = try stop()
        try start(taskId: taskId)
    }

    @discardableResult
    func recoverIfNeeded() throws -> TimeEntry? {
        let recovered = try timeEntryRepository.recoverRunningEntry(endAt: nowProvider())
        try refreshCurrentRunningEntry()
        return recovered
    }

    func refreshCurrentRunningEntry() throws {
        currentRunningEntry = try timeEntryRepository.fetchRunningEntry()
    }
}
