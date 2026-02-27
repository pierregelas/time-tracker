import Foundation

struct DayInterval: Equatable {
    let startUTC: Int64
    let endUTC: Int64
}

struct BreakInterval: Equatable {
    let startAt: Int64
    let endAt: Int64

    var duration: Int64 {
        max(0, endAt - startAt)
    }
}

enum TimeCalculations {
    static func localDayIntervalUTC(dateLocal: Date, timeZone: TimeZone) -> DayInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dayStart = calendar.startOfDay(for: dateLocal)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return DayInterval(
            startUTC: Int64(dayStart.timeIntervalSince1970),
            endUTC: Int64(dayEnd.timeIntervalSince1970)
        )
    }

    static func intersect(
        entryStart: Int64,
        entryEndOrNow: Int64,
        periodStart: Int64,
        periodEnd: Int64
    ) -> Int64 {
        let effectiveStart = max(entryStart, periodStart)
        let effectiveEnd = min(entryEndOrNow, periodEnd)
        return max(0, effectiveEnd - effectiveStart)
    }

    static func workedSecondsForDay(
        entries: [TimeEntry],
        dayInterval: DayInterval,
        now: Int64 = Int64(Date().timeIntervalSince1970)
    ) -> Int64 {
        entries.reduce(0) { total, entry in
            let end = entry.endAt ?? now
            return total + intersect(
                entryStart: entry.startAt,
                entryEndOrNow: end,
                periodStart: dayInterval.startUTC,
                periodEnd: dayInterval.endUTC
            )
        }
    }

    static func targetSecondsForDay(workingHours: [WorkingHour], weekday: Int) -> Int64 {
        guard let day = workingHours.first(where: { $0.weekday == weekday }) else {
            return 0
        }
        return Int64(day.minutesTarget) * 60
    }

    static func deltaSeconds(workedSeconds: Int64, targetSeconds: Int64) -> Int64 {
        workedSeconds - targetSeconds
    }

    static func missingSeconds(workedSeconds: Int64, targetSeconds: Int64) -> Int64 {
        guard targetSeconds > 0 else {
            return 0
        }
        return max(0, targetSeconds - workedSeconds)
    }

    static func computeBreaksForDay(
        entries: [TimeEntry],
        dayInterval: DayInterval,
        minGap: Int64,
        maxGap: Int64,
        now: Int64 = Int64(Date().timeIntervalSince1970)
    ) -> [BreakInterval] {
        guard dayInterval.endUTC > dayInterval.startUTC else {
            return []
        }

        let projected = entries
            .compactMap { entry -> BreakInterval? in
                let effectiveEnd = entry.endAt ?? now
                let start = max(entry.startAt, dayInterval.startUTC)
                let end = min(effectiveEnd, dayInterval.endUTC)
                guard end > start else { return nil }
                return BreakInterval(startAt: start, endAt: end)
            }
            .sorted { lhs, rhs in
                if lhs.startAt == rhs.startAt {
                    return lhs.endAt < rhs.endAt
                }
                return lhs.startAt < rhs.startAt
            }

        guard !projected.isEmpty else {
            return []
        }

        var merged: [BreakInterval] = [projected[0]]
        for interval in projected.dropFirst() {
            let last = merged[merged.count - 1]
            if interval.startAt <= last.endAt {
                merged[merged.count - 1] = BreakInterval(
                    startAt: last.startAt,
                    endAt: max(last.endAt, interval.endAt)
                )
            } else {
                merged.append(interval)
            }
        }

        var breaks: [BreakInterval] = []
        for index in 0..<(merged.count - 1) {
            let previous = merged[index]
            let next = merged[index + 1]
            let gap = next.startAt - previous.endAt
            if gap >= minGap && gap <= maxGap {
                breaks.append(BreakInterval(startAt: previous.endAt, endAt: next.startAt))
            }
        }

        return breaks
    }
}
