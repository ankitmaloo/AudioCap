import SwiftUI

@MainActor
struct ProcessSelectionView: View {
    @State private var processController = AudioProcessController()
    
    @State private var tap: ProcessTap?
    @State private var recorder: ProcessTapRecorder?

    var body: some View {
        // The Section has been removed. We use a VStack for structure.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source")
                        .font(.headline)
                    
                    if let activeProcess = processController.activeProcess {
                        // This logic remains the same
                        if let tap {
                            if let errorMessage = tap.errorMessage {
                                Text(errorMessage)
                                    .font(.headline)
                                    .foregroundStyle(.red)
                            } else if let recorder {
                                RecordingView(recorder: recorder)
                                    .onChange(of: recorder.isRecording) { wasRecording, isRecording in
                                        processController.isRecording = isRecording
                                        if wasRecording, !isRecording {
                                            createRecorder(for: activeProcess)
                                        }
                                    }
                            }
                        }
                    } else {
                        Text("Waiting for an application to play audio...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center) // Center the waiting text
                    }
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



