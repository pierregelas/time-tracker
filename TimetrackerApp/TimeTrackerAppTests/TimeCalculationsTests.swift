import Foundation
import Testing
@testable import TimeTrackerApp

struct TimeCalculationsTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test func breakDetectedWhenGapWithinThreshold() {
        let day = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 5, 12, 0),
            timeZone: utc
        )

        let entries = [
            makeEntry(start: makeDate(2026, 1, 5, 9, 0), end: makeDate(2026, 1, 5, 12, 0)),
            makeEntry(start: makeDate(2026, 1, 5, 12, 30), end: makeDate(2026, 1, 5, 17, 0))
        ]

        let breaks = TimeCalculations.computeBreaksForDay(
            entries: entries,
            dayInterval: day,
            minGap: 5 * 60,
            maxGap: 240 * 60
        )

        #expect(breaks.count == 1)
        #expect(breaks[0].duration == 30 * 60)
    }

    @Test func breakIgnoredWhenGapTooShort() {
        let day = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 5, 12, 0),
            timeZone: utc
        )

        let entries = [
            makeEntry(start: makeDate(2026, 1, 5, 9, 0), end: makeDate(2026, 1, 5, 12, 0)),
            makeEntry(start: makeDate(2026, 1, 5, 12, 3), end: makeDate(2026, 1, 5, 17, 0))
        ]

        let breaks = TimeCalculations.computeBreaksForDay(
            entries: entries,
            dayInterval: day,
            minGap: 5 * 60,
            maxGap: 240 * 60
        )

        #expect(breaks.isEmpty)
    }

    @Test func breakIgnoredWhenGapTooLong() {
        let day = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 5, 12, 0),
            timeZone: utc
        )

        let entries = [
            makeEntry(start: makeDate(2026, 1, 5, 8, 0), end: makeDate(2026, 1, 5, 9, 0)),
            makeEntry(start: makeDate(2026, 1, 5, 14, 30), end: makeDate(2026, 1, 5, 17, 0))
        ]

        let breaks = TimeCalculations.computeBreaksForDay(
            entries: entries,
            dayInterval: day,
            minGap: 5 * 60,
            maxGap: 240 * 60
        )

        #expect(breaks.isEmpty)
    }

    @Test func workedSecondsSplitAcrossMidnight() {
        let entry = makeEntry(start: makeDate(2026, 1, 5, 23, 0), end: makeDate(2026, 1, 6, 1, 0))

        let dayOne = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 5, 12, 0),
            timeZone: utc
        )
        let dayTwo = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 6, 12, 0),
            timeZone: utc
        )

        let dayOneWorked = TimeCalculations.workedSecondsForDay(entries: [entry], dayInterval: dayOne)
        let dayTwoWorked = TimeCalculations.workedSecondsForDay(entries: [entry], dayInterval: dayTwo)

        #expect(dayOneWorked == 3600)
        #expect(dayTwoWorked == 3600)
    }

    @Test func workedTargetDeltaAndMissingAreComputed() {
        let day = TimeCalculations.localDayIntervalUTC(
            dateLocal: makeDate(2026, 1, 5, 12, 0),
            timeZone: utc
        )
        let entries = [
            makeEntry(start: makeDate(2026, 1, 5, 9, 0), end: makeDate(2026, 1, 5, 13, 0)),
            makeEntry(start: makeDate(2026, 1, 5, 14, 0), end: makeDate(2026, 1, 5, 18, 0))
        ]

        let worked = TimeCalculations.workedSecondsForDay(entries: entries, dayInterval: day)
        let target = TimeCalculations.targetSecondsForDay(
            workingHours: [WorkingHour(weekday: 1, minutesTarget: 450)],
            weekday: 1
        )
        let delta = TimeCalculations.deltaSeconds(workedSeconds: worked, targetSeconds: target)
        let missing = TimeCalculations.missingSeconds(workedSeconds: worked, targetSeconds: target)
        let missingWhenTargetZero = TimeCalculations.missingSeconds(workedSeconds: 0, targetSeconds: 0)

        #expect(worked == 8 * 3600)
        #expect(target == 450 * 60)
        #expect(delta == 1800)
        #expect(missing == 0)
        #expect(missingWhenTargetZero == 0)
    }

    private func makeEntry(start: Date, end: Date?) -> TimeEntry {
        TimeEntry(
            id: nil,
            taskId: 1,
            startAt: Int64(start.timeIntervalSince1970),
            endAt: end.map { Int64($0.timeIntervalSince1970) },
            note: nil,
            source: .manual,
            createdAt: 0,
            updatedAt: 0
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(
            timeZone: utc,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
