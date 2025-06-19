import SwiftUI

@MainActor
struct ProcessSelectionView: View {
    @State private var processController = AudioProcessController()
    
    @State private var tap: ProcessTap?
    @State private var recorder: ProcessTapRecorder?

    var body: some View {
        Section {
            if let activeProcess = processController.activeProcess {
                if let tap {
                    if let errorMessage = tap.errorMessage {
                        Text(errorMessage)
                            .font(.headline)
                            .foregroundStyle(.red)
                    } else if let recorder {
                        RecordingView(recorder: recorder)
                            // --- THIS IS THE KEY CHANGE ---
                            .onChange(of: recorder.isRecording) { wasRecording, isRecording in
                                // Inform the controller about the recording status change.
                                // This will "pause" and "resume" the reload timer.
                                processController.isRecording = isRecording

                                // If recording just finished, create a new recorder for the next session.
                                if wasRecording, !isRecording {
                                    createRecorder(for: activeProcess)
                                }
                            }
                    }
                }
            } else {
                Text("Waiting for an application to play audio...")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Source")
                .font(.headline)
        }
        .task {
            processController.activate()
        }
        .onChange(of: processController.activeProcess) { oldValue, newValue in
            guard newValue != oldValue else { return }

            if let newValue {
                setupRecording(for: newValue)
            } else {
                teardownTap()
            }
        }
    }

    private func setupRecording(for process: AudioProcess) {
        let newTap = ProcessTap(process: process)
        self.tap = newTap
        newTap.activate()

        createRecorder(for: process)
    }

    private func createRecorder(for process: AudioProcess) {
        let filename = "\(process.name)-\(Int(Date.now.timeIntervalSinceReferenceDate))"
        let audioFileURL = URL.applicationSupport.appendingPathComponent(filename, conformingTo: .wav)
        
        guard let tap = self.tap else { return }
        
        let newRecorder = ProcessTapRecorder(fileURL: audioFileURL, tap: tap)
        self.recorder = newRecorder
    }

    private func teardownTap() {
        tap?.invalidate()
        tap = nil
        recorder = nil
    }
}


// ... (URL extension is unchanged) ...
extension URL {
    static var applicationSupport: URL {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let subdir = appSupport.appending(path: "AudioCap", directoryHint: .isDirectory)
            if !FileManager.default.fileExists(atPath: subdir.path) {
                try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
            }
            return subdir
        } catch {
            assertionFailure("Failed to get application support directory: \(error)")

            return FileManager.default.temporaryDirectory
        }
    }
}
