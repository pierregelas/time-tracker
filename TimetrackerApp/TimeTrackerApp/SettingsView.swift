import AppKit
import Observation
import SwiftUI
import GRDB

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let appDataDidChange = Notification.Name("appDataDidChange")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    GroupBox("Working Hours") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            // Optional header row
                            GridRow {
                                Text("Day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)

                                Text("Minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 120, alignment: .trailing)
                            }
                            .padding(.bottom, 4)

                            ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                                GridRow {
                                    Text(viewModel.label(for: weekday))
                                        .frame(width: 60, alignment: .leading)

                                    TextField("0", text: viewModel.bindingForWorkingMinutes(weekday: weekday))
                                        .multilineTextAlignment(.trailing)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                }
                            }
                        }
                        .padding(.top, 6)
                    }

                    GroupBox("Break rules") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Text("Min gap (minutes)")
                                    .frame(width: 160, alignment: .leading)

                                TextField("0", text: $viewModel.minGapMinutesInput)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }

                            GridRow {
                                Text("Max gap (minutes)")
                                    .frame(width: 160, alignment: .leading)

                                TextField("0", text: $viewModel.maxGapMinutesInput)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                        .padding(.top, 6)
                    }

                    GroupBox("Data") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Export all time entries to a CSV file.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Export CSV…") {
                                viewModel.exportCSV()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }

                    #if DEBUG
                    GroupBox("Debug") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Development helpers for acceptance test scenarios.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button("Seed Test Data") {
                                    viewModel.seedTestData()
                                }

                                Button("Reset Data", role: .destructive) {
                                    viewModel.resetData()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }
                    #endif
                }
                .padding(20)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Export completed", isPresented: $viewModel.showSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage)
            }
            .task {
                viewModel.load()
            }
        }
        // Fix a stable sheet size to avoid macOS Form/Grid weird measuring + clipping
        .frame(width: 640, height: 460)
    }
}

@Observable
final class SettingsViewModel {
    private let settingsRepository: SettingsRepository = GRDBSettingsRepository()
    private let csvExporter: CSVExporting = CSVExportService()

    let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Monday...Sunday for UI

    var workingMinutesInput: [Int: String] = [:]
    var minGapMinutesInput = ""
    var maxGapMinutesInput = ""

    var showError = false
    var errorMessage = ""
    var showSuccess = false
    var successMessage = ""

    #if DEBUG
    private let debugDataService = DebugDataService()
    #endif

    func load() {
        do {
            let hours = try settingsRepository.getWorkingHours()
            for weekday in orderedWeekdays {
                let value = hours.first(where: { $0.weekday == weekday })?.minutesTarget ?? 0
                workingMinutesInput[weekday] = String(value)
            }

            let breakRules = try settingsRepository.getBreakRules()
            minGapMinutesInput = String(breakRules.minGapMinutes)
            maxGapMinutesInput = String(breakRules.maxGapMinutes)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func bindingForWorkingMinutes(weekday: Int) -> Binding<String> {
        Binding(
            get: { self.workingMinutesInput[weekday, default: "0"] },
            set: { self.workingMinutesInput[weekday] = $0 }
        )
    }

    func label(for weekday: Int) -> String {
        switch weekday {
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "Sun"
        }
    }

    @discardableResult
    func save() -> Bool {
        do {
            let workingHours = try buildWorkingHours()
            let rules = try buildBreakRules()

            try settingsRepository.setWorkingHours(workingHours)
            try settingsRepository.setBreakRules(rules)

            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            return true
        } catch {
            setError(error.localizedDescription)
            return false
        }
    }

    private func buildWorkingHours() throws -> [WorkingHour] {
        var result: [WorkingHour] = []
        for weekday in orderedWeekdays {
            let value = try parseNonNegativeInt(workingMinutesInput[weekday, default: "0"], field: "Working hours")
            result.append(WorkingHour(weekday: weekday, minutesTarget: value))
        }
        return result
    }

    private func buildBreakRules() throws -> BreakRules {
        let minValue = try parseNonNegativeInt(minGapMinutesInput, field: "Min gap")
        let maxValue = try parseNonNegativeInt(maxGapMinutesInput, field: "Max gap")

        guard minValue <= maxValue else {
            throw ValidationError(message: "Min gap must be less than or equal to max gap.")
        }

        return BreakRules(minGapMinutes: minValue, maxGapMinutes: maxValue)
    }

    private func parseNonNegativeInt(_ raw: String, field: String) throws -> Int {
        guard let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ValidationError(message: "\(field) must be a number.")
        }
        guard value >= 0 else {
            throw ValidationError(message: "\(field) must be greater than or equal to 0.")
        }
        return value
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func exportCSV() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a destination folder for the CSV export."
        panel.prompt = "Export"

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            return
        }

        let hasScopedAccess = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let rows = try csvExporter.export(toDirectory: directoryURL)
            successMessage = "CSV export created successfully with \(rows) row\(rows == 1 ? "" : "s")."
            showSuccess = true
        } catch {
            setError(Self.exportErrorMessage(from: error))
        }
    }

    private static func exportErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.localizedDescription) (code: \(nsError.code))"
    }

    #if DEBUG
    func seedTestData() {
        do {
            try debugDataService.seedAcceptanceTestData()
            NotificationCenter.default.post(name: .appDataDidChange, object: nil)
        } catch {
            setError(error.localizedDescription)
        }
    }

    func resetData() {
        do {
            try debugDataService.resetAllData()
            NotificationCenter.default.post(name: .appDataDidChange, object: nil)
        } catch {
            setError(error.localizedDescription)
        }
    }
    #endif
}

struct ValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

#if DEBUG
final class DebugDataService {
    private let dbQueue: any DatabaseWriter

    init(dbQueue: any DatabaseWriter = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    func resetAllData() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM time_entry")
            try db.execute(sql: "DELETE FROM task_tag")
            try db.execute(sql: "DELETE FROM tag")
            try db.execute(sql: "DELETE FROM task")
            try db.execute(sql: "DELETE FROM project")
            try db.execute(sql: "DELETE FROM category")
        }
    }

    func seedAcceptanceTestData(now: Date = Date()) throws {
        try resetAllData()

        let nowEpoch = Int64(now.timeIntervalSince1970)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)

        func localTimestamp(hour: Int, minute: Int) -> Int64 {
            let value = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
            return Int64(value.timeIntervalSince1970)
        }

        try dbQueue.write { db in
            let clientCategoryId = try insertCategory(db: db, name: "Client", sortOrder: 0, now: nowEpoch)
            let persoCategoryId = try insertCategory(db: db, name: "Perso", sortOrder: 1, now: nowEpoch)

            let projetAId = try insertProject(db: db, categoryId: clientCategoryId, name: "Projet A", sortOrder: 0, now: nowEpoch)
            let projetBId = try insertProject(db: db, categoryId: persoCategoryId, name: "Projet B", sortOrder: 0, now: nowEpoch)

            let montageTaskId = try insertTask(db: db, projectId: projetAId, parentTaskId: nil, name: "Montage", sortOrder: 0, now: nowEpoch)
            let derushTaskId = try insertTask(db: db, projectId: projetAId, parentTaskId: montageTaskId, name: "Derush", sortOrder: 0, now: nowEpoch)
            let timelineTaskId = try insertTask(db: db, projectId: projetAId, parentTaskId: montageTaskId, name: "Timeline", sortOrder: 1, now: nowEpoch)
            let motionTaskId = try insertTask(db: db, projectId: projetAId, parentTaskId: nil, name: "Motion", sortOrder: 1, now: nowEpoch)

            _ = try insertTask(db: db, projectId: projetBId, parentTaskId: nil, name: "Admin", sortOrder: 0, now: nowEpoch)
            let sportTaskId = try insertTask(db: db, projectId: projetBId, parentTaskId: nil, name: "Sport", sortOrder: 1, now: nowEpoch)
            let runningTaskId = try insertTask(db: db, projectId: projetBId, parentTaskId: sportTaskId, name: "Running", sortOrder: 0, now: nowEpoch)

            let montageTagId = try insertTag(db: db, name: "montage", now: nowEpoch)
            let motionTagId = try insertTag(db: db, name: "motion", now: nowEpoch)

            try insertTaskTag(db: db, taskId: montageTaskId, tagId: montageTagId, now: nowEpoch)
            try insertTaskTag(db: db, taskId: derushTaskId, tagId: montageTagId, now: nowEpoch)
            try insertTaskTag(db: db, taskId: timelineTaskId, tagId: montageTagId, now: nowEpoch)
            try insertTaskTag(db: db, taskId: motionTaskId, tagId: motionTagId, now: nowEpoch)

            try insertTimeEntry(db: db, taskId: motionTaskId, startAt: localTimestamp(hour: 9, minute: 0), endAt: localTimestamp(hour: 10, minute: 0), source: "manual", now: nowEpoch)
            try insertTimeEntry(db: db, taskId: derushTaskId, startAt: localTimestamp(hour: 10, minute: 15), endAt: localTimestamp(hour: 11, minute: 0), source: "manual", now: nowEpoch)
            try insertTimeEntry(db: db, taskId: runningTaskId, startAt: localTimestamp(hour: 11, minute: 15), endAt: localTimestamp(hour: 12, minute: 0), source: "manual", now: nowEpoch)
        }
    }

    private func insertCategory(db: Database, name: String, sortOrder: Int, now: Int64) throws -> Int64 {
        try db.execute(
            sql: "INSERT INTO category (name, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?)",
            arguments: [name, sortOrder, now, now]
        )
        return db.lastInsertedRowID
    }

    private func insertProject(db: Database, categoryId: Int64, name: String, sortOrder: Int, now: Int64) throws -> Int64 {
        try db.execute(
            sql: "INSERT INTO project (category_id, name, color, sort_order, is_archived, created_at, updated_at) VALUES (?, ?, NULL, ?, 0, ?, ?)",
            arguments: [categoryId, name, sortOrder, now, now]
        )
        return db.lastInsertedRowID
    }

    private func insertTask(db: Database, projectId: Int64, parentTaskId: Int64?, name: String, sortOrder: Int, now: Int64) throws -> Int64 {
        try db.execute(
            sql: "INSERT INTO task (project_id, parent_task_id, name, sort_order, is_archived, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)",
            arguments: [projectId, parentTaskId, name, sortOrder, now, now]
        )
        return db.lastInsertedRowID
    }

    private func insertTag(db: Database, name: String, now: Int64) throws -> Int64 {
        try db.execute(
            sql: "INSERT INTO tag (name, created_at, updated_at) VALUES (?, ?, ?)",
            arguments: [name, now, now]
        )
        return db.lastInsertedRowID
    }

    private func insertTaskTag(db: Database, taskId: Int64, tagId: Int64, now: Int64) throws {
        try db.execute(
            sql: "INSERT INTO task_tag (task_id, tag_id, created_at) VALUES (?, ?, ?)",
            arguments: [taskId, tagId, now]
        )
    }

    private func insertTimeEntry(db: Database, taskId: Int64, startAt: Int64, endAt: Int64, source: String, now: Int64) throws {
        try db.execute(
            sql: "INSERT INTO time_entry (task_id, start_at, end_at, note, source, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            arguments: [taskId, startAt, endAt, "Seeded debug entry", source, now, now]
        )
    }
}
#endif
