import SwiftUI

struct NotesView: View {
    @StateObject private var notesManager = NotesManager()
    
    var body: some View {
        NavigationView {
            List(notesManager.notes) { note in
                NavigationLink(destination: Text(note.title)) {
                    VStack(alignment: .leading) {
                        Text(note.title)
                            .font(.headline)
                        Text(note.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Recordings")
            
            Text("Select a recording to play it back.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}