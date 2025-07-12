import Foundation

struct Note: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var transcription: String? = nil
    var todos: [String] = []
    
    var creationDate: Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    
    var title: String {
        url.deletingPathExtension().lastPathComponent
    }
}
