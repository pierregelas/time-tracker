import Observation
import SwiftUI

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Working Hours") {
                    ForEach(viewModel.orderedWeekdays, id: \.self) { weekday in
                        HStack {
                            Text(viewModel.label(for: weekday))
                            Spacer()
                            TextField("Minutes", text: viewModel.bindingForWorkingMinutes(weekday: weekday))
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                    }
                }

                Section("Break rules") {
                    HStack {
                        Text("Min gap (minutes)")
                        Spacer()
                        TextField("0", text: $viewModel.minGapMinutesInput)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    HStack {
                        Text("Max gap (minutes)")
                        Spacer()
                        TextField("0", text: $viewModel.maxGapMinutesInput)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
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
            .task {
                viewModel.load()
            }
        }
        .frame(minWidth: 420, minHeight: 380)
    }
}

@Observable
final class SettingsViewModel {
    private let settingsRepository: SettingsRepository = GRDBSettingsRepository()

    let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1] // Monday...Sunday for UI

    var workingMinutesInput: [Int: String] = [:]
    var minGapMinutesInput = ""
    var maxGapMinutesInput = ""

    var showError = false
    var errorMessage = ""

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
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
