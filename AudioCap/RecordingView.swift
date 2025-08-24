import SwiftUI

@MainActor
struct RecordingView: View {
    let recorder: ProcessTapRecorder
    @EnvironmentObject private var notesManager: NotesManager
    @State private var isProcessing = false
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""

    @State private var lastRecordingURL: URL?

    var body: some View {
        Section {
            HStack {
                if recorder.isRecording {
                    Button("Stop") {
                        recorder.stop()
                    }
                    .id("button")
                } else {
                    Button("Start") {
                        handlingErrors { try recorder.start() }
                    }
                    .id("button")

                    if let lastRecordingURL {
                        FileProxyView(url: lastRecordingURL)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if isProcessing {
                    ProgressView()
                        .padding(.leading)
                }
            }
            .animation(.smooth, value: recorder.isRecording)
            .animation(.smooth, value: lastRecordingURL)
            .onChange(of: recorder.isRecording) { _, newValue in
                if !newValue {
                    lastRecordingURL = recorder.fileURL
                    processRecording(url: recorder.fileURL)
                }
            }
        } header: {
            HStack {
                RecordingIndicator(appIcon: recorder.process.icon, isRecording: recorder.isRecording)

                Text(recorder.isRecording ? "Recording from \(recorder.process.name)" : "Ready to Record from \(recorder.process.name)")
                    .font(.headline)
                    .contentTransition(.identity)
            }
        }
    }

    private func processRecording(url: URL) {
        isProcessing = true
        Task {
            do {
                guard !geminiAPIKey.isEmpty else {
                    print("Gemini API Key is not set.")
                    isProcessing = false
                    return
                }
                let gemini = Gemini(apiKey: geminiAPIKey) // Replace with your actual API key
                let transcription = try await gemini.transcribe(audioURL: url)
                let todos = try await gemini.extractTodos(from: transcription)

                notesManager.updateNote(url: url, transcription: transcription, todos: todos)

            } catch {
                print("Error processing recording: \(error)")
            }
            isProcessing = false
        }
    }

    private func handlingErrors(perform block: () throws -> Void) {
        do {
            try block()
        } catch {
            /// "handling" in the function name might not be entirely true 😅
            NSAlert(error: error).runModal()
        }
    }
}

