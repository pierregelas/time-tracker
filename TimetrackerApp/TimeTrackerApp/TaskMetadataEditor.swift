import SwiftUI

struct TaskMetadataDraft {
    var tagsRaw: String
    var note: String

    static let empty = TaskMetadataDraft(tagsRaw: "", note: "")
}

struct TaskMetadataEditorSection: View {
    @Binding var tagsRaw: String
    @Binding var note: String

    var body: some View {
        TextField("Tags (comma or space separated)", text: $tagsRaw)
        VStack(alignment: .leading, spacing: 8) {
            Text("Task notes")
            TextEditor(text: $note)
                .frame(minHeight: 120)
        }
    }
}

struct TaskMetadataStore {
    private let taskRepository: TaskRepository
    private let tagRepository: TagRepository

    init(
        taskRepository: TaskRepository = GRDBTaskRepository(),
        tagRepository: TagRepository = GRDBTagRepository()
    ) {
        self.taskRepository = taskRepository
        self.tagRepository = tagRepository
    }

    func load(taskId: Int64?) throws -> TaskMetadataDraft {
        guard let taskId else { return .empty }

        let task = try taskRepository
            .list(includeArchived: true)
            .first(where: { $0.id == taskId })
        let tags = try tagRepository.getTagsForTask(taskId: taskId).map(\.name)

        return TaskMetadataDraft(
            tagsRaw: tags.joined(separator: ", "),
            note: task?.note ?? ""
        )
    }

    func save(taskId: Int64, draft: TaskMetadataDraft) throws {
        guard var task = try taskRepository
            .list(includeArchived: true)
            .first(where: { $0.id == taskId }) else {
            return
        }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        task.note = trimmedNote.isEmpty ? nil : trimmedNote
        _ = try taskRepository.update(task)

        try tagRepository.setTagsForTask(taskId: taskId, parseTags(draft.tagsRaw))
    }

    private func parseTags(_ raw: String) throws -> [String] {
        let chunks = raw
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)

        return try Array(Set(chunks.map { try tagRepository.normalizeTag($0) })).sorted()
    }
}
