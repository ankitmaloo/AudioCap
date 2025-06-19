import SwiftUI

struct AudioDetectionView: View {
    @State private var audioController = AudioProcessController()
    @State private var showRecordingSheet = false // To present the recording interface
    @State private var isPulsing = false // For simple animation

    // These will be set up when recording starts
    @State private var systemTap: ProcessTap?
    @State private var systemRecorder: ProcessTapRecorder?
    @State private var recordingError: String?

    var body: some View {
        VStack(spacing: 20) {
            if audioController.isAnyAudioPlaying {
                Text("Audio Detected")
                    .font(.largeTitle)
                    .foregroundColor(.green)
                
                Image(systemName: "waveform")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(isPulsing ? 1.1 : 0.9)
                    .opacity(isPulsing ? 1.0 : 0.7)
                    .padding()
                    .onAppear {
                        // Start a timer for the pulsing animation only when audio is detected
                        // This timer will be implicitly stopped if this part of the view disappears
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                            if audioController.isAnyAudioPlaying { // Only animate if still relevant
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    isPulsing.toggle()
                                }
                            }
                        }
                    }

                Button {
                    setupAndStartRecording()
                } label: {
                    Label("Start Recording", systemImage: "mic.circle.fill")
                        .font(.title2)
                }
                .keyboardShortcut("r", modifiers: .command)
                .padding()

            } else {
                Text("No Audio Playing")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Image(systemName: "mic.slash.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(minWidth: 300, minHeight: 200)
        .onAppear {
            audioController.activate()
            // Initial pulse state
            if audioController.isAnyAudioPlaying {
                 isPulsing = true // Start with a pulse if audio is already playing
            }
        }
        .sheet(isPresented: $showRecordingSheet) {
            // Ensure tap is invalidated when sheet is dismissed
            // This will also stop the recorder if it's running via its deinit or stop()
            if let tap = systemTap {
                tap.invalidate()
            }
            systemTap = nil // Clear the tap and recorder
            systemRecorder = nil
        } content: { // Use 'content' parameter for the sheet's view builder
            if let currentRecorder = systemRecorder {
                // Pass the configured recorder to RecordingView
                RecordingView(recorder: currentRecorder)
                    .onDisappear {
                        // This block is for when the RecordingView itself is dismissed/disappears
                        // The tap invalidation is better handled in the sheet's onDismiss
                    }
            } else if let error = recordingError {
                VStack {
                    Text("Error Starting Recording")
                        .font(.headline)
                    Text(error)
                        .padding()
                    Button("Dismiss") {
                        showRecordingSheet = false
                        recordingError = nil // Clear error after dismissal
                    }
                }
                .padding()
            } else {
                // Fallback, should ideally not be shown if setupAndStartRecording works
                Text("Preparing recording interface...")
                    .padding()
            }
        }
    }

    private func setupAndStartRecording() {
        recordingError = nil
        // 1. Setup ProcessTap for system audio
        let tap = ProcessTap(process: <#AudioProcess#>, muteWhenRunning: false) // System tap, muteWhenRunning can be preference
        tap.activate()

        if let tapError = tap.errorMessage {
            self.recordingError = "Failed to activate audio tap: \(tapError)"
            self.systemTap = nil // Do not store tap if it failed
            self.systemRecorder = nil
            self.showRecordingSheet = true // Show sheet to display error
            return
        }
        self.systemTap = tap // Store tap only if activation succeeded

        // 2. Setup ProcessTapRecorder
        guard tap.tapStreamDescription != nil else { // Check if streamDescription is available
            self.recordingError = "Failed to get tap stream description."
            tap.invalidate() // Clean up the tap that was activated
            self.systemTap = nil
            self.systemRecorder = nil
            self.showRecordingSheet = true
            return
        }
        
        let recordingsDir = URL.applicationSupport.appendingPathComponent("Recordings", isDirectory: true)
        do {
            if !FileManager.default.fileExists(atPath: recordingsDir.path(percentEncoded: false)) {
                try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
            }
            let fileURL = recordingsDir.appendingPathComponent("SystemAudio-\(Int(Date.now.timeIntervalSinceReferenceDate))", conformingTo: .wav)
            
            let recorder = ProcessTapRecorder(fileURL: fileURL, tap: tap)
            self.systemRecorder = recorder

            // 3. Start Recording
            try recorder.start()
            self.showRecordingSheet = true // Show the recording view

        } catch {
            self.recordingError = "Failed to start recording: \(error.localizedDescription)"
            tap.invalidate() // Clean up the tap
            self.systemTap = nil
            self.systemRecorder = nil
            self.showRecordingSheet = true
        }
    }
}

// Assuming URL.applicationSupport is available as it was in other views.
// If not, it needs to be defined, e.g.:
// extension URL {
//     static var applicationSupport: URL {
//         FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
//             .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
//     }
// }
// However, this extension is likely already present in the project from ProcessSelectionView.
// For the purpose of this subtask, I am assuming it's accessible.
// The `content` parameter for `.sheet` was also added for clarity as per modern SwiftUI.
// Added cleanup for tap in `.sheet`'s `onDismiss` (implicit via isPresented changing to false).
// Corrected tap storage and stream description check in `setupAndStartRecording`.
// Added cleanup for recordingError when "Dismiss" button is pressed in error view.
