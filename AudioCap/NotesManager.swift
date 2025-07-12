import Foundation

@MainActor
final class NotesManager: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let directory: URL

    init() {
        self.directory = URL.applicationSupport

        loadNotes()
    }

    func loadNotes() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            self.notes = urls.map { url in
                var note = Note(url: url)
                let transcriptionURL = url.appendingPathExtension("txt")
                if let transcription = try? String(contentsOf: transcriptionURL) {
                    note.transcription = transcription
                    note.todos = transcription.components(separatedBy: .whitespacesAndNewlines)
                        .filter { $0.uppercased().hasPrefix("TODO") }
                }
                return note
            }.sorted(by: { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast })
        } catch {
            print("Failed to load notes:", error)
        }
    }

    func updateNote(url: URL, transcription: String, todos: [String]) {
        if let index = notes.firstIndex(where: { $0.url == url }) {
            notes[index].transcription = transcription
            notes[index].todos = todos
            let transcriptionURL = url.appendingPathExtension("txt")
            try? transcription.write(to: transcriptionURL, atomically: true, encoding: .utf8)
        }
    }
}