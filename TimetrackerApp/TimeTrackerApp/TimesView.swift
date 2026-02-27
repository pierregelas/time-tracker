import Observation
import SwiftUI

struct TimesView: View {
    @State private var viewModel = TimesViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                navigationBar
                headerStats
                tagFilter
                timelineList
            }
            .padding()
            .navigationTitle("Times")
            .toolbar {
                Button("Add Entry") {
                    viewModel.presentAddEntry()
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                viewModel.reloadAll()
            }
            .onChange(of: viewModel.selectedDate) {
                viewModel.reloadForSelectedDate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
                viewModel.reloadForSelectedDate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDataDidChange)) { _ in
                viewModel.reloadAll()
            }
            .sheet(item: $viewModel.activeEditor) { editor in
                TimeEntryEditorSheet(
                    editor: editor,
                    tasks: viewModel.tasks,
                    taskPath: viewModel.pathForTask,
                    onSave: { payload in
                        viewModel.saveEntry(payload, editor: editor)
                    },
                    onDelete: {
                        if case .edit(let entry) = editor {
                            viewModel.deleteEntry(entry)
                        }
                    }
                )
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            Button(action: viewModel.goToPreviousDay) {
                Label("Previous day", systemImage: "chevron.left")
            }
            .labelStyle(.iconOnly)

            Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).day().month().year())
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button("Today") { viewModel.goToToday() }

            Button(action: viewModel.goToNextDay) {
                Label("Next day", systemImage: "chevron.right")
            }
            .labelStyle(.iconOnly)
        }
    }

    private var headerStats: some View {
        HStack(spacing: 16) {
            statCard(title: "Worked", value: viewModel.formattedWorked)
            statCard(title: "Target", value: viewModel.formattedTarget)
            statCard(title: "Delta", value: viewModel.formattedDelta)
            statCard(title: "Missing", value: viewModel.formattedMissing)
        }
    }

    private var tagFilter: some View {
        HStack(spacing: 8) {
            Text("Tag filter")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Type tag", text: $viewModel.tagInput)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.tagInput) {
                    viewModel.refreshTagSuggestions()
                }

            Menu("Suggestions") {
                if viewModel.tagSuggestions.isEmpty {
                    Text("No tags")
                } else {
                    ForEach(viewModel.tagSuggestions, id: \.name) { tag in
                        Button(tag.name) {
                            viewModel.selectTag(tag.name)
                        }
                    }
                }
            }

            if viewModel.selectedTag != nil {
                Button("Clear") {
                    viewModel.clearTagFilter()
                }
            }
        }
    }

    private var timelineList: some View {
        List {
            if viewModel.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No entries today")
                    Button("Add entry") {
                        viewModel.presentAddEntry()
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.items) { item in
                    switch item {
                    case .entry(let entryView):
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entryView.title)
                                Spacer()
                                Text(entryView.range)
                                    .monospacedDigit()
                                Text(entryView.duration)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            if !entryView.note.isEmpty {
                                Text(entryView.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.presentEdit(entryView.raw)
                        }
                    case .breakItem(let breakView):
                        HStack {
                            Label("Break", systemImage: "cup.and.saucer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(breakView.range)
                                .monospacedDigit()
                            Text(breakView.duration)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

@Observable
final class TimesViewModel {
    struct EntryItemView {
        let raw: TimeEntry
        let title: String
        let range: String
        let duration: String
        let note: String
    }

    struct BreakItemView {
        let startAt: Int64
        let range: String
        let duration: String
    }

    enum TimelineItem: Identifiable {
        case entry(EntryItemView)
        case breakItem(BreakItemView)

        var id: String {
            switch self {
            case .entry(let entry):
                return "entry-\(entry.raw.id ?? 0)-\(entry.raw.startAt)"
            case .breakItem(let breakItem):
                return "break-\(breakItem.startAt)-\(breakItem.duration)"
            }
        }
    }

    enum Editor: Identifiable {
        case add
        case edit(TimeEntry)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let entry): return "edit-\(entry.id ?? 0)"
            }
        }
    }

    struct EntryPayload {
        var taskId: Int64
        var startAt: Int64
        var endAt: Int64
        var note: String
    }

    private let categoryRepository: CategoryRepository = GRDBCategoryRepository()
    private let projectRepository: ProjectRepository = GRDBProjectRepository()
    private let taskRepository: TaskRepository = GRDBTaskRepository()
    private let timeEntryRepository: TimeEntryRepository = GRDBTimeEntryRepository()
    private let settingsRepository: SettingsRepository = GRDBSettingsRepository()
    private let tagRepository: TagRepository = GRDBTagRepository()

    var selectedDate = Date()
    var workedSeconds: Int64 = 0
    var targetSeconds: Int64 = 0
    var deltaSeconds: Int64 = 0
    var missingSeconds: Int64 = 0
    var items: [TimelineItem] = []

    var tasks: [Task] = []
    var taskById: [Int64: Task] = [:]
    var projectById: [Int64: Project] = [:]

    var selectedTag: String?
    var tagInput = ""
    var tagSuggestions: [Tag] = []

    var activeEditor: Editor?
    var showError = false
    var errorMessage = ""

    private var dayEntries: [TimeEntry] = []

    var formattedWorked: String { formatSignedDuration(workedSeconds, forceSign: false) }
    var formattedTarget: String { formatSignedDuration(targetSeconds, forceSign: false) }
    var formattedDelta: String { formatSignedDuration(deltaSeconds, forceSign: true) }
    var formattedMissing: String { formatSignedDuration(missingSeconds, forceSign: false) }

    func reloadAll() {
        do {
            try loadTaskCatalog()
            reloadForSelectedDate()
            refreshTagSuggestions()
        } catch {
            setError(error)
        }
    }

    func reloadForSelectedDate() {
        do {
            dayEntries = try timeEntryRepository.fetchDayEntries(dateLocal: selectedDate)
            rebuildItemsAndStats()
        } catch {
            setError(error)
        }
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() {
        selectedDate = Date()
    }

    func presentAddEntry() {
        activeEditor = .add
    }

    func presentEdit(_ entry: TimeEntry) {
        activeEditor = .edit(entry)
    }

    func saveEntry(_ payload: EntryPayload, editor: Editor) {
        do {
            guard payload.endAt > payload.startAt else {
                throw TimesValidationError.invalidRange
            }

            let excludedId: Int64?
            switch editor {
            case .add:
                excludedId = nil
            case .edit(let entry):
                excludedId = entry.id
            }

            if try timeEntryRepository.existsOverlap(startAt: payload.startAt, endAt: payload.endAt, excludingId: excludedId) {
                throw TimesValidationError.overlap
            }

            switch editor {
            case .add:
                _ = try timeEntryRepository.createManualEntry(
                    taskId: payload.taskId,
                    startAt: payload.startAt,
                    endAt: payload.endAt,
                    note: payload.note.isEmpty ? nil : payload.note
                )
            case .edit(let entry):
                var updated = entry
                updated.taskId = payload.taskId
                updated.startAt = payload.startAt
                updated.endAt = payload.endAt
                updated.note = payload.note.isEmpty ? nil : payload.note
                _ = try timeEntryRepository.updateEntry(updated)
            }
            activeEditor = nil
            reloadForSelectedDate()
        } catch {
            setError(error)
        }
    }

    func deleteEntry(_ entry: TimeEntry) {
        do {
            guard let id = entry.id else { return }
            try timeEntryRepository.deleteEntry(id: id)
            activeEditor = nil
            reloadForSelectedDate()
        } catch {
            setError(error)
        }
    }

    func refreshTagSuggestions() {
        do {
            tagSuggestions = try tagRepository.searchTags(prefix: tagInput)
        } catch {
            setError(error)
        }
    }

    func selectTag(_ tag: String) {
        selectedTag = tag
        tagInput = tag
        rebuildItemsAndStats()
    }

    func clearTagFilter() {
        selectedTag = nil
        tagInput = ""
        rebuildItemsAndStats()
        refreshTagSuggestions()
    }

    func pathForTask(_ taskId: Int64) -> String {
        guard let task = taskById[taskId] else { return "Unknown task" }
        let projectName = projectById[task.projectId]?.name ?? "Unknown project"

        if let parentId = task.parentTaskId, let parent = taskById[parentId] {
            return "\(projectName) > \(parent.name) > \(task.name)"
        }
        return "\(projectName) > \(task.name)"
    }

    private func loadTaskCatalog() throws {
        let categories = try categoryRepository.list()
        var loadedProjects: [Project] = []
        var loadedTasks: [Task] = []

        for category in categories {
            let projects = try projectRepository.listByCategory(categoryId: category.id ?? 0, includeArchived: true)
            loadedProjects.append(contentsOf: projects)

            for project in projects {
                let tasks = try taskRepository.listByProject(projectId: project.id ?? 0, includeArchived: true)
                loadedTasks.append(contentsOf: tasks)
            }
        }

        self.tasks = loadedTasks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.taskById = Dictionary(uniqueKeysWithValues: loadedTasks.compactMap { task in
            guard let id = task.id else { return nil }
            return (id, task)
        })
        self.projectById = Dictionary(uniqueKeysWithValues: loadedProjects.compactMap { project in
            guard let id = project.id else { return nil }
            return (id, project)
        })
    }

    private func rebuildItemsAndStats() {
        let calendar = Calendar.current
        let now = Int64(Date().timeIntervalSince1970)
        let weekday = calendar.component(.weekday, from: selectedDate)
        let dayInterval = TimeCalculations.localDayIntervalUTC(dateLocal: selectedDate, timeZone: .current)

        let visibleEntries = filteredEntries(dayEntries)
            .sorted { $0.startAt < $1.startAt }

        do {
            let workingHours = try settingsRepository.getWorkingHours()
            let breakRules = try settingsRepository.getBreakRules()

            workedSeconds = TimeCalculations.workedSecondsForDay(entries: visibleEntries, dayInterval: dayInterval, now: now)
            targetSeconds = TimeCalculations.targetSecondsForDay(workingHours: workingHours, weekday: weekday)
            deltaSeconds = TimeCalculations.deltaSeconds(workedSeconds: workedSeconds, targetSeconds: targetSeconds)
            missingSeconds = TimeCalculations.missingSeconds(workedSeconds: workedSeconds, targetSeconds: targetSeconds)

            let breaks = TimeCalculations.computeBreaksForDay(
                entries: visibleEntries,
                dayInterval: dayInterval,
                minGap: Int64(breakRules.minGapMinutes) * 60,
                maxGap: Int64(breakRules.maxGapMinutes) * 60,
                now: now
            )

            items = buildTimelineItems(entries: visibleEntries, breaks: breaks, now: now)
        } catch {
            setError(error)
        }
    }

    private func filteredEntries(_ entries: [TimeEntry]) -> [TimeEntry] {
        guard let selectedTag else { return entries }
        let normalizedTag = selectedTag.lowercased()

        return entries.filter { entry in
            guard let tags = try? tagRepository.getTagsForTask(taskId: entry.taskId) else {
                return false
            }
            return tags.contains { $0.name == normalizedTag }
        }
    }

    private func buildTimelineItems(entries: [TimeEntry], breaks: [BreakInterval], now: Int64) -> [TimelineItem] {
        var timeline: [TimelineItem] = entries.map { entry in
            let end = entry.endAt ?? now
            let row = EntryItemView(
                raw: entry,
                title: pathForTask(entry.taskId),
                range: "\(formatClock(entry.startAt)) - \(formatClock(end))",
                duration: formatSignedDuration(max(0, end - entry.startAt), forceSign: false),
                note: entry.note ?? ""
            )
            return .entry(row)
        }

        timeline.append(contentsOf: breaks.map { gap in
            .breakItem(
                BreakItemView(
                    startAt: gap.startAt,
                    range: "\(formatClock(gap.startAt)) - \(formatClock(gap.endAt))",
                    duration: formatSignedDuration(gap.duration, forceSign: false)
                )
            )
        })

        return timeline.sorted { lhs, rhs in
            timelineStart(lhs) < timelineStart(rhs)
        }
    }

    private func timelineStart(_ item: TimelineItem) -> Int64 {
        switch item {
        case .entry(let entry):
            return entry.raw.startAt
        case .breakItem(let breakItem):
            return breakItem.startAt
        }
    }

    private func formatClock(_ epoch: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(epoch)).formatted(date: .omitted, time: .shortened)
    }

    private func formatSignedDuration(_ seconds: Int64, forceSign: Bool) -> String {
        let sign = seconds < 0 ? "-" : (forceSign && seconds > 0 ? "+" : "")
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        return "\(sign)\(hours)h \(String(format: "%02d", minutes))m"
    }

    private func setError(_ error: Error) {
        if let error = error as? TimesValidationError {
            switch error {
            case .invalidRange:
                errorMessage = "End time must be after start time."
            case .overlap:
                errorMessage = "Chevauchement avec une autre entrée : corrige les horaires."
            }
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}

enum TimesValidationError: Error {
    case invalidRange
    case overlap
}

struct TimeEntryEditorSheet: View {
    let editor: TimesViewModel.Editor
    let tasks: [Task]
    let taskPath: (Int64) -> String
    let onSave: (TimesViewModel.EntryPayload) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTaskId: Int64 = 0
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Task", selection: $selectedTaskId) {
                    ForEach(tasks) { task in
                        if let id = task.id {
                            Text(taskPath(id)).tag(id)
                        }
                    }
                }

                DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])

                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle(editorTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .edit = editor {
                    ToolbarItem {
                        Button("Delete", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let payload = TimesViewModel.EntryPayload(
                            taskId: selectedTaskId,
                            startAt: Int64(startTime.timeIntervalSince1970),
                            endAt: Int64(endTime.timeIntervalSince1970),
                            note: note
                        )
                        onSave(payload)
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeForm()
            }
        }
        .frame(minWidth: 460, minHeight: 300)
    }

    private var editorTitle: String {
        switch editor {
        case .add:
            return "Add Entry"
        case .edit:
            return "Edit Entry"
        }
    }

    private func initializeForm() {
        if selectedTaskId != 0 { return }

        switch editor {
        case .add:
            selectedTaskId = tasks.first?.id ?? 0
        case .edit(let entry):
            selectedTaskId = entry.taskId
            startTime = Date(timeIntervalSince1970: TimeInterval(entry.startAt))
            endTime = Date(timeIntervalSince1970: TimeInterval(entry.endAt ?? entry.startAt))
            note = entry.note ?? ""
        }
    }
}
