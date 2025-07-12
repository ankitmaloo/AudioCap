import Foundation

@MainActor
final class NotesManager: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let directory: URL

    init() {
        self.directory = URL.applicationSupport ?? FileManager.default.temporaryDirectory

        loadNotes()
    }

    func loadNotes() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            self.notes = urls.map { Note(url: $0) }.sorted(by: { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast })
        } catch {
            print("Failed to load notes:", error)
        }
    }
}