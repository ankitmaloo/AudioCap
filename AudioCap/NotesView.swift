import SwiftUI

struct NotesView: View {
    @EnvironmentObject private var notesManager: NotesManager
    @State private var audioService = AudioCapService()
    @State private var isProcessing = false
    @State private var currentRecordingURLs: (system: URL, mic: URL)?
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Recording Controls
                recordingControlsView
                
                // Notes List
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
            }
            .navigationTitle("Recordings")
            
            Text("Select a recording to play it back.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var recordingControlsView: some View {
        VStack(spacing: 12) {
            if let activeProcess = audioService.getCurrentActiveProcess() {
                HStack {
                    Image(nsImage: activeProcess.icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading) {
                        Text(activeProcess.name)
                            .font(.headline)
                        Text(audioService.isRecording ? "Recording..." : "Ready to record")
                            .font(.caption)
                            .foregroundColor(audioService.isRecording ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button(audioService.isRecording ? "Stop" : "Record") {
                        if audioService.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else if audioService.isAnyAudioPlaying() {
                Text("Detecting audio sources...")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Text("Waiting for audio to play...")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            if let errorMessage = audioService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
    
    private func startRecording() {
        guard let activeProcess = audioService.getCurrentActiveProcess() else { return }
        
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let systemAudioURL = URL.applicationSupport.appendingPathComponent("\(activeProcess.name)-system-\(timestamp).wav")
        let microphoneURL = URL.applicationSupport.appendingPathComponent("\(activeProcess.name)-mic-\(timestamp).wav")
        
        do {
            try audioService.startRecording(systemAudioURL: systemAudioURL, microphoneURL: microphoneURL)
            currentRecordingURLs = (system: systemAudioURL, mic: microphoneURL)
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        guard let recordingURLs = currentRecordingURLs else { return }
        
        audioService.stopRecording()
        
        // Process the recordings
        processRecordings(systemAudioURL: recordingURLs.system, microphoneURL: recordingURLs.mic)
        
        // Clear the current recording URLs
        currentRecordingURLs = nil
    }
    
    private func processRecordings(systemAudioURL: URL, microphoneURL: URL) {
        isProcessing = true
        Task {
            do {
                guard !geminiAPIKey.isEmpty else {
                    print("Gemini API Key is not set.")
                    isProcessing = false
                    return
                }
                
                let gemini = Gemini(apiKey: geminiAPIKey)
                
                // Process the system audio for transcription (usually has the main content)
                let transcription = try await gemini.transcribe(audioURL: systemAudioURL)
                let todos = try await gemini.extractTodos(from: transcription)
                
                // Update notes manager with the system audio file (main recording)
                notesManager.updateNote(url: systemAudioURL, transcription: transcription, todos: todos)
                
                // Reload notes to show the new recording
                notesManager.loadNotes()
                
            } catch {
                print("Error processing recordings: \(error)")
            }
            isProcessing = false
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
