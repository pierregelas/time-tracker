import Testing
@testable import TimeTrackerApp

struct StatisticsAggregationTests {
    @Test func aggregatesWorkedProjectAndTagTotalsWithIntersections() {
        let entries: [TimeEntry] = [
            TimeEntry(id: 1, taskId: 100, startAt: 5, endAt: 12, note: nil, source: .manual, createdAt: 0, updatedAt: 0),
            TimeEntry(id: 2, taskId: 100, startAt: 12, endAt: 16, note: nil, source: .manual, createdAt: 0, updatedAt: 0),
            TimeEntry(id: 3, taskId: 200, startAt: 16, endAt: 25, note: nil, source: .manual, createdAt: 0, updatedAt: 0)
        ]

        let aggregate = StatisticsAggregation.aggregate(
            entries: entries,
            startUTC: 10,
            endUTC: 20,
            now: 30,
            taskToProject: [100: 1, 200: 2],
            projectNames: [1: "Alpha", 2: "Beta"],
            tagsByTask: [100: ["swift", "deep"], 200: ["deep"]]
        )

        #expect(aggregate.workedSeconds == 10)
        #expect(aggregate.projectTotals == [NamedSeconds(name: "Alpha", seconds: 6), NamedSeconds(name: "Beta", seconds: 4)])
        #expect(aggregate.tagTotals == [NamedSeconds(name: "deep", seconds: 10), NamedSeconds(name: "swift", seconds: 6)])
    }
}
