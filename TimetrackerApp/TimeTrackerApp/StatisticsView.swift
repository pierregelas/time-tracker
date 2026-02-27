import SwiftUI

struct StatisticsView: View {
    @State private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            List {
                periodSection

                Section("Totals") {
                    statRow(title: "Worked", value: viewModel.formatDuration(viewModel.workedSeconds))
                    statRow(title: "Target", value: viewModel.formatDuration(viewModel.targetSeconds))
                    statRow(
                        title: viewModel.deltaSeconds >= 0 ? "Overtime" : "Undertime",
                        value: viewModel.formatDuration(abs(viewModel.deltaSeconds))
                    )
                }

                Section("Total by Project") {
                    if viewModel.projectTotals.isEmpty {
                        Text("No data")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.projectTotals) { total in
                            statRow(title: total.name, value: viewModel.formatDuration(total.seconds))
                        }
                    }
                }

                Section("Total by Tag") {
                    if viewModel.tagTotals.isEmpty {
                        Text("No data")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tagTotals) { total in
                            statRow(title: total.name, value: viewModel.formatDuration(total.seconds))
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                viewModel.reload()
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
                viewModel.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDataDidChange)) { _ in
                viewModel.reload()
            }
        }
    }

    private var periodSection: some View {
        Section {
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

struct NamedSeconds: Identifiable, Equatable {
    let name: String
    let seconds: Int64

    var id: String { name }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case thisMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        }
    }
}

struct StatisticsAggregate {
    let workedSeconds: Int64
    let projectTotals: [NamedSeconds]
    let tagTotals: [NamedSeconds]
}

enum StatisticsAggregation {
    static func aggregate(
        entries: [TimeEntry],
        startUTC: Int64,
        endUTC: Int64,
        now: Int64,
        taskToProject: [Int64: Int64],
        projectNames: [Int64: String],
        tagsByTask: [Int64: [String]]
    ) -> StatisticsAggregate {
        var worked: Int64 = 0
        var byProject: [String: Int64] = [:]
        var byTag: [String: Int64] = [:]

        for entry in entries {
            let contribution = TimeCalculations.intersect(
                entryStart: entry.startAt,
                entryEndOrNow: entry.endAt ?? now,
                periodStart: startUTC,
                periodEnd: endUTC
            )
            guard contribution > 0 else { continue }

            worked += contribution

            if let projectId = taskToProject[entry.taskId], let projectName = projectNames[projectId] {
                byProject[projectName, default: 0] += contribution
            }

            for tag in tagsByTask[entry.taskId] ?? [] {
                byTag[tag, default: 0] += contribution
            }
        }

        return StatisticsAggregate(
            workedSeconds: worked,
            projectTotals: sortedTotals(byProject),
            tagTotals: sortedTotals(byTag)
        )
    }

    private static func sortedTotals(_ values: [String: Int64]) -> [NamedSeconds] {
        values
            .map { NamedSeconds(name: $0.key, seconds: $0.value) }
            .sorted { lhs, rhs in
                if lhs.seconds == rhs.seconds {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.seconds > rhs.seconds
            }
    }
}

@Observable
final class StatisticsViewModel {
    private let timeEntryRepository: TimeEntryRepository = GRDBTimeEntryRepository()
    private let settingsRepository: SettingsRepository = GRDBSettingsRepository()
    private let categoryRepository: CategoryRepository = GRDBCategoryRepository()
    private let projectRepository: ProjectRepository = GRDBProjectRepository()
    private let taskRepository: TaskRepository = GRDBTaskRepository()
    private let tagRepository: TagRepository = GRDBTagRepository()

    var selectedPeriod: StatisticsPeriod = .thisWeek

    var workedSeconds: Int64 = 0
    var targetSeconds: Int64 = 0
    var deltaSeconds: Int64 = 0
    var projectTotals: [NamedSeconds] = []
    var tagTotals: [NamedSeconds] = []

    var showError = false
    var errorMessage = ""

    func reload(now: Date = Date()) {
        do {
            let interval = periodInterval(for: selectedPeriod, now: now)
            let entries = try timeEntryRepository.fetchEntries(in: interval.startUTC, interval.endUTC)
            let nowEpoch = Int64(now.timeIntervalSince1970)

            let (taskToProject, projectNames) = try loadTaskProjectMaps()
            let tagsByTask = try loadTagsByTask(Array(taskToProject.keys))

            let aggregate = StatisticsAggregation.aggregate(
                entries: entries,
                startUTC: interval.startUTC,
                endUTC: interval.endUTC,
                now: nowEpoch,
                taskToProject: taskToProject,
                projectNames: projectNames,
                tagsByTask: tagsByTask
            )

            let workingHours = try settingsRepository.getWorkingHours()
            let target = targetSecondsForPeriod(
                startLocal: interval.startLocal,
                endLocal: interval.endLocal,
                workingHours: workingHours
            )

            workedSeconds = aggregate.workedSeconds
            targetSeconds = target
            deltaSeconds = TimeCalculations.deltaSeconds(workedSeconds: workedSeconds, targetSeconds: targetSeconds)
            projectTotals = aggregate.projectTotals
            tagTotals = aggregate.tagTotals
        } catch {
            setError(error)
        }
    }

    func formatDuration(_ seconds: Int64) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }

    private func loadTaskProjectMaps() throws -> ([Int64: Int64], [Int64: String]) {
        let categories = try categoryRepository.list()
        var taskToProject: [Int64: Int64] = [:]
        var projectNames: [Int64: String] = [:]

        for category in categories {
            let projects = try projectRepository.listByCategory(categoryId: category.id ?? 0, includeArchived: true)
            for project in projects {
                guard let projectId = project.id else { continue }
                projectNames[projectId] = project.name

                let tasks = try taskRepository.listByProject(projectId: projectId, includeArchived: true)
                for task in tasks {
                    guard let taskId = task.id else { continue }
                    taskToProject[taskId] = projectId
                }
            }
        }

        return (taskToProject, projectNames)
    }

    private func loadTagsByTask(_ taskIds: [Int64]) throws -> [Int64: [String]] {
        var tagsByTask: [Int64: [String]] = [:]
        for taskId in taskIds {
            let tags = try tagRepository.getTagsForTask(taskId: taskId)
            tagsByTask[taskId] = tags.map(\.name)
        }
        return tagsByTask
    }

    private func periodInterval(for period: StatisticsPeriod, now: Date) -> (startLocal: Date, endLocal: Date, startUTC: Int64, endUTC: Int64) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let dayStart = calendar.startOfDay(for: now)
        let startLocal: Date
        let endLocal: Date

        switch period {
        case .today:
            startLocal = dayStart
            endLocal = calendar.date(byAdding: .day, value: 1, to: startLocal) ?? startLocal
        case .thisWeek:
            let weekday = calendar.component(.weekday, from: dayStart)
            let daysSinceMonday = (weekday + 5) % 7
            startLocal = calendar.date(byAdding: .day, value: -daysSinceMonday, to: dayStart) ?? dayStart
            endLocal = calendar.date(byAdding: .day, value: 7, to: startLocal) ?? startLocal
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: dayStart)
            startLocal = calendar.date(from: components) ?? dayStart
            endLocal = calendar.date(byAdding: .month, value: 1, to: startLocal) ?? startLocal
        }

        let startUTC = TimeCalculations.localDayIntervalUTC(dateLocal: startLocal, timeZone: .current).startUTC
        let endUTC = TimeCalculations.localDayIntervalUTC(dateLocal: endLocal, timeZone: .current).startUTC
        return (startLocal, endLocal, startUTC, endUTC)
    }

    private func targetSecondsForPeriod(startLocal: Date, endLocal: Date, workingHours: [WorkingHour]) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        var day = calendar.startOfDay(for: startLocal)
        let end = calendar.startOfDay(for: endLocal)

        var total: Int64 = 0
        while day < end {
            let weekday = calendar.component(.weekday, from: day)
            total += TimeCalculations.targetSecondsForDay(workingHours: workingHours, weekday: weekday)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? end
        }

        return total
    }

    private func setError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

#Preview {
    StatisticsView()
}
