import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var notesManager: NotesManager
    
    var body: some View {
        NavigationView {
            List(notesManager.notes) { note in
                NavigationLink(destination: NoteDetailView(note: note)) {
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

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.title)
                .font(.largeTitle)
                .padding(.bottom, 5)

            if let transcription = note.transcription {
                Text("Transcription")
                    .font(.headline)
                Text(transcription)
                    .padding(.bottom, 10)
            }

            if !note.todos.isEmpty {
                Text("TODOs")
                    .font(.headline)
                ForEach(note.todos, id: \.self) { todo in
                    Text("- \(todo)")
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
