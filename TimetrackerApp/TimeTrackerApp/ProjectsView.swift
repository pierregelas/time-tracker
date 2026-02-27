import Observation
import SwiftUI

struct ProjectsView: View {
    @Environment(TimerService.self) private var timerService
    @State private var viewModel = ProjectsViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.hierarchy) { categoryNode in
                    DisclosureGroup(
                        isExpanded: binding(for: categoryNode.category.id, in: $viewModel.expandedCategories),
                        content: {
                            ForEach(categoryNode.projects) { projectNode in
                                DisclosureGroup(
                                    isExpanded: binding(for: projectNode.project.id, in: $viewModel.expandedProjects),
                                    content: {
                                        ForEach(projectNode.tasks) { taskNode in
                                            taskRow(taskNode.task, isSubtask: false)

                                            if !taskNode.subtasks.isEmpty {
                                                DisclosureGroup(
                                                    isExpanded: binding(for: taskNode.task.id, in: $viewModel.expandedTasks),
                                                    content: {
                                                        ForEach(taskNode.subtasks) { subtask in
                                                            taskRow(subtask, isSubtask: true)
                                                        }
                                                    },
                                                    label: { EmptyView() }
                                                )
                                                .labelsHidden()
                                            }
                                        }
                                    },
                                    label: {
                                        HStack {
                                            Circle()
                                                .fill(Color(hex: projectNode.project.color) ?? .gray)
                                                .frame(width: 10, height: 10)
                                            Text(projectNode.project.name)
                                            if projectNode.project.isArchived {
                                                Text("archived").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button("Edit") { viewModel.presentProjectEditor(projectNode.project) }
                                                .buttonStyle(.borderless)
                                            Button("+ Task") { viewModel.presentTaskEditor(project: projectNode.project, parentTask: nil) }
                                                .buttonStyle(.borderless)
                                        }
                                    }
                                )
                            }
                        },
                        label: {
                            HStack {
                                Text(categoryNode.category.name)
                                    .font(.headline)
                                Spacer()
                                Button("Rename") { viewModel.presentCategoryRename(categoryNode.category) }
                                    .buttonStyle(.borderless)
                                Button("+ Project") { viewModel.presentProjectEditor(nil, categoryId: categoryNode.category.id ?? 0) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItemGroup {
                    Button("Add Category") { viewModel.presentCategoryAdd() }
                    Button("Refresh") { viewModel.reload(with: timerService) }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                viewModel.reload(with: timerService)
            }
            .onChange(of: timerService.currentRunningEntry?.id) {
                viewModel.runningTaskId = timerService.currentRunningEntry?.taskId
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDataDidChange)) { _ in
                viewModel.reload(with: timerService)
            }
            .sheet(item: $viewModel.activeEditor) { editor in
                editorView(editor)
            }
        }
    }

    private func taskRow(_ task: Task, isSubtask: Bool) -> some View {
        HStack {
            if isSubtask { Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary) }
            Text(task.name)
            if viewModel.runningTaskId == task.id {
                Label("Running", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Spacer()
            Button(viewModel.runningTaskId == task.id ? "Stop" : "Start") {
                viewModel.toggleTimer(for: task, timerService: timerService)
            }
            .buttonStyle(.borderless)
            Button("Edit") { viewModel.presentTaskEdit(task) }
                .buttonStyle(.borderless)
            if !isSubtask {
                Button("+ Sub") { viewModel.presentTaskEditor(project: nil, parentTask: task) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(viewModel.runningTaskId == task.id ? Color.green.opacity(0.15) : Color.clear)
    }

    @ViewBuilder
    private func editorView(_ editor: ProjectsViewModel.Editor) -> some View {
        switch editor {
        case .addCategory:
            CategoryEditSheet(title: "Add Category", initialName: "") { name in
                viewModel.addCategory(name: name)
            }
        case .renameCategory(let category):
            CategoryEditSheet(title: "Rename Category", initialName: category.name) { name in
                viewModel.renameCategory(category: category, name: name)
            } onDelete: {
                viewModel.deleteCategory(category)
            }
        case .editProject(let project, let defaultCategoryId):
            ProjectEditSheet(project: project, categories: viewModel.categories, defaultCategoryId: defaultCategoryId) { payload in
                viewModel.saveProject(payload)
            } onDelete: {
                if let project { viewModel.deleteProject(project) }
            }
        case .editTask(let task, let projectId, let parentTaskId):
            TaskEditSheet(task: task, projects: viewModel.projects, projectId: projectId, parentTaskId: parentTaskId) { payload in
                viewModel.saveTask(payload)
            } onDelete: {
                if let task { viewModel.deleteTask(task) }
            }
        }
    }

    private func binding(for id: Int64?, in set: Binding<Set<Int64>>) -> Binding<Bool> {
        let safeId = id ?? -1
        return Binding(
            get: { set.wrappedValue.contains(safeId) },
            set: { expanded in
                if expanded { set.wrappedValue.insert(safeId) } else { set.wrappedValue.remove(safeId) }
            }
        )
    }
}

@Observable
final class ProjectsViewModel {
    struct CategoryNode: Identifiable {
        let category: Category
        let projects: [ProjectNode]
        var id: Int64 { category.id ?? 0 }
    }

    struct ProjectNode: Identifiable {
        let project: Project
        let tasks: [TaskNode]
        var id: Int64 { project.id ?? 0 }
    }

    struct TaskNode: Identifiable {
        let task: Task
        let subtasks: [Task]
        var id: Int64 { task.id ?? 0 }
    }

    struct ProjectPayload {
        var project: Project?
        var name: String
        var categoryId: Int64
        var color: String
        var isArchived: Bool
    }

    struct TaskPayload {
        var task: Task?
        var name: String
        var projectId: Int64
        var parentTaskId: Int64?
        var tagsRaw: String
        var note: String
    }

    enum Editor: Identifiable {
        case addCategory
        case renameCategory(Category)
        case editProject(Project?, Int64)
        case editTask(Task?, Int64?, Int64?)

        var id: String {
            switch self {
            case .addCategory: return "addCategory"
            case .renameCategory(let c): return "renameCategory\(c.id ?? 0)"
            case .editProject(let p, let c): return "editProject\(p?.id ?? 0)-\(c)"
            case .editTask(let t, let p, let parent): return "editTask\(t?.id ?? 0)-\(p ?? 0)-\(parent ?? 0)"
            }
        }
    }

    private let categoryRepository: CategoryRepository = GRDBCategoryRepository()
    private let projectRepository: ProjectRepository = GRDBProjectRepository()
    private let taskRepository: TaskRepository = GRDBTaskRepository()
    private let tagRepository: TagRepository = GRDBTagRepository()

    var hierarchy: [CategoryNode] = []
    var categories: [Category] = []
    var projects: [Project] = []
    var runningTaskId: Int64?
    var expandedCategories = Set<Int64>()
    var expandedProjects = Set<Int64>()
    var expandedTasks = Set<Int64>()

    var activeEditor: Editor?
    var showError = false
    var errorMessage = ""

    private var timerService: TimerService?

    func reload(with timerService: TimerService) {
        self.timerService = timerService
        do {
            let categories = try categoryRepository.list()
            self.categories = categories
            self.projects = []
            self.hierarchy = try categories.map { category in
                let projects = try projectRepository.listByCategory(categoryId: category.id ?? 0, includeArchived: true)
                self.projects.append(contentsOf: projects)
                let projectNodes = try projects.map { project in
                    let tasks = try taskRepository.listByProject(projectId: project.id ?? 0, includeArchived: true)
                    let roots = tasks.filter { $0.parentTaskId == nil }
                    let taskNodes = roots.map { task in
                        TaskNode(task: task, subtasks: tasks.filter { $0.parentTaskId == task.id })
                    }
                    return ProjectNode(project: project, tasks: taskNodes)
                }
                return CategoryNode(category: category, projects: projectNodes)
            }
            runningTaskId = timerService.currentRunningEntry?.taskId
        } catch {
            setError(error)
        }
    }

    func toggleTimer(for task: Task, timerService: TimerService) {
        do {
            guard let taskId = task.id else { return }
            if runningTaskId == taskId {
                _ = try timerService.stop()
            } else {
                try timerService.start(taskId: taskId)
            }
            runningTaskId = timerService.currentRunningEntry?.taskId
        } catch {
            setError(error)
        }
    }

    func presentCategoryAdd() { activeEditor = .addCategory }
    func presentCategoryRename(_ category: Category) { activeEditor = .renameCategory(category) }
    func presentProjectEditor(_ project: Project?, categoryId: Int64 = 0) { activeEditor = .editProject(project, categoryId) }
    func presentTaskEditor(project: Project?, parentTask: Task?) {
        activeEditor = .editTask(nil, project?.id, parentTask?.id)
    }

    func presentTaskEdit(_ task: Task) {
        activeEditor = .editTask(task, task.projectId, task.parentTaskId)
    }

    func addCategory(name: String) {
        do {
            _ = try categoryRepository.create(name: name, sortOrder: categories.count)
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func renameCategory(category: Category, name: String) {
        do {
            var updated = category
            updated.name = name
            _ = try categoryRepository.update(updated)
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func deleteCategory(_ category: Category) {
        do {
            if let id = category.id { try categoryRepository.delete(id: id) }
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func saveProject(_ payload: ProjectPayload) {
        do {
            if var project = payload.project {
                project.name = payload.name
                project.categoryId = payload.categoryId
                project.color = payload.color.isEmpty ? nil : payload.color
                project.isArchived = payload.isArchived
                _ = try projectRepository.update(project)
            } else {
                _ = try projectRepository.create(categoryId: payload.categoryId, name: payload.name, color: payload.color.isEmpty ? nil : payload.color, sortOrder: projects.count)
            }
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func deleteProject(_ project: Project) {
        do {
            if let id = project.id { try projectRepository.delete(id: id) }
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func saveTask(_ payload: TaskPayload) {
        do {
            if var task = payload.task {
                task.name = payload.name
                task.projectId = payload.projectId
                task.parentTaskId = payload.parentTaskId
                task.note = payload.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : payload.note
                _ = try taskRepository.update(task)
                if let id = task.id {
                    try tagRepository.setTagsForTask(taskId: id, parseTags(payload.tagsRaw))
                }
            } else {
                let created = try taskRepository.create(projectId: payload.projectId, parentTaskId: payload.parentTaskId, name: payload.name, note: payload.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : payload.note, sortOrder: 0)
                if let id = created.id {
                    try tagRepository.setTagsForTask(taskId: id, parseTags(payload.tagsRaw))
                }
            }
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    func deleteTask(_ task: Task) {
        do {
            if let id = task.id { try taskRepository.delete(id: id) }
            activeEditor = nil
            refreshAfterMutation()
        } catch {
            setError(error)
        }
    }

    private func refreshAfterMutation() {
        if let timerService {
            reload(with: timerService)
        }
    }

    private func parseTags(_ raw: String) throws -> [String] {
        let chunks = raw
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)
        return try Array(Set(chunks.map { try tagRepository.normalizeTag($0) })).sorted()
    }

    private func setError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}

struct CategoryEditSheet: View {
    let title: String
    @State var initialName: String
    var onSave: (String) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $initialName)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(initialName); dismiss() }
                        .disabled(initialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let onDelete {
                    ToolbarItem(placement: .destructiveAction) { Button("Delete", role: .destructive) { onDelete(); dismiss() } }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 180)
    }
}

struct ProjectEditSheet: View {
    let project: Project?
    let categories: [Category]
    let defaultCategoryId: Int64
    var onSave: (ProjectsViewModel.ProjectPayload) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var categoryId: Int64 = 0
    @State private var color = ""
    @State private var isArchived = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $categoryId) {
                    ForEach(categories) { c in
                        Text(c.name).tag(c.id ?? 0)
                    }
                }
                TextField("Color hex (e.g. #4F46E5)", text: $color)
                Toggle("Archived", isOn: $isArchived)
            }
            .navigationTitle(project == nil ? "Add Project" : "Edit Project")
            .onAppear {
                name = project?.name ?? ""
                categoryId = project?.categoryId ?? defaultCategoryId
                color = project?.color ?? ""
                isArchived = project?.isArchived ?? false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(.init(project: project, name: name, categoryId: categoryId, color: color, isArchived: isArchived))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || categoryId == 0)
                }
                if let onDelete {
                    ToolbarItem(placement: .destructiveAction) { Button("Delete", role: .destructive) { onDelete(); dismiss() } }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}

struct TaskEditSheet: View {
    let task: Task?
    let projects: [Project]
    let projectId: Int64?
    let parentTaskId: Int64?
    var onSave: (ProjectsViewModel.TaskPayload) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedProjectId: Int64 = 0
    @State private var tagsRaw = ""
    @State private var note = ""

    private let tagRepo: TagRepository = GRDBTagRepository()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Project", selection: $selectedProjectId) {
                    ForEach(projects) { p in Text(p.name).tag(p.id ?? 0) }
                }
                TextField("Tags (comma or space separated)", text: $tagsRaw)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle(title)
            .onAppear {
                name = task?.name ?? ""
                selectedProjectId = task?.projectId ?? projectId ?? 0
                if let id = task?.id,
                   let tags = try? tagRepo.getTagsForTask(taskId: id).map(\.name) {
                    tagsRaw = tags.joined(separator: ", ")
                }
                note = task?.note ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(.init(task: task, name: name, projectId: selectedProjectId, parentTaskId: parentTaskId, tagsRaw: tagsRaw, note: note))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedProjectId == 0)
                }
                if let onDelete {
                    ToolbarItem(placement: .destructiveAction) { Button("Delete", role: .destructive) { onDelete(); dismiss() } }
                }
            }
        }
        .frame(minWidth: 430, minHeight: 250)
    }

    private var title: String {
        if task != nil { return "Edit Task" }
        return parentTaskId == nil ? "Add Task" : "Add Sub-task"
    }
}

private extension Color {
    init?(hex: String?) {
        guard var hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        hex = hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
