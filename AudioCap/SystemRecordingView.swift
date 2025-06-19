import SwiftUI
import OSLog
import AVFoundation

@Observable
final class SystemTapManager {
    var tap: ProcessTap?
    var recorder: ProcessTapRecorder?
    var errorMessage: String?

    private let logger = Logger(subsystem: kAppSubsystem, category: "SystemTapManager")

    init() {
        setupSystemRecording()
    }

    func setupSystemRecording() {
        logger.info("Setting up system recording")
        if tap == nil {
            tap = ProcessTap(muteWhenRunning: false) // Or true, depending on desired default
        }

        guard let currentTap = tap else {
            errorMessage = "Failed to initialize audio tap."
            logger.error("Tap is nil during setup")
            return
        }

        if !currentTap.activated {
            currentTap.activate()
        }

        if let tapError = currentTap.errorMessage {
            self.errorMessage = "Error activating tap: \(tapError)"
            logger.error("Error activating tap: \(tapError)")
            // Don't proceed to create recorder if tap activation failed
            return
        }

        // Clear previous error message if tap activation succeeded
        self.errorMessage = nil
        createRecorder()
    }

    func createRecorder() {
        guard let currentTap = tap, currentTap.activated, currentTap.errorMessage == nil else {
            logger.warning("Cannot create recorder, tap not ready or has errors.")
            if currentTap?.errorMessage != nil {
                self.errorMessage = currentTap?.errorMessage
            } else if !(currentTap?.activated ?? false) {
                 self.errorMessage = "Tap not activated. Please try again."
            }
            return
        }

        do {
            let documentsPath = URL.applicationSupport.appendingPathComponent("Recordings", isDirectory: true)
            if !FileManager.default.fileExists(atPath: documentsPath.path(percentEncoded: false)) {
                try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)
            }
            let fileUrl = documentsPath.appendingPathComponent("SystemAudio-\(Int(Date.now.timeIntervalSinceReferenceDate))", conformingTo: .wav)

            recorder = ProcessTapRecorder(fileURL: fileUrl, tap: currentTap)
            logger.info("Recorder created with file: \(fileUrl.lastPathComponent)")
            self.errorMessage = nil // Clear any previous error
        } catch {
            logger.error("Failed to create ProcessTapRecorder: \(error, privacy: .public)")
            self.errorMessage = "Failed to create recorder: \(error.localizedDescription)"
            recorder = nil // Ensure recorder is nil if creation fails
        }
    }

    func teardownTap() {
        logger.info("Tearing down tap")
        if let currentRecorder = recorder, currentRecorder.isRecording {
            currentRecorder.stop()
            logger.info("Stopped active recording.")
        }
        recorder = nil

        if let currentTap = tap {
            currentTap.invalidate()
            logger.info("Invalidated tap.")
        }
        tap = nil
        // Keep errorMessage until a new setup is attempted
    }

    deinit {
        logger.info("SystemTapManager deinit")
        teardownTap()
    }
}

struct SystemRecordingView: View {
    @State private var manager = SystemTapManager()

    var body: some View {
        VStack {
            if let errorMessage = manager.errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry Setup") {
                        manager.errorMessage = nil // Clear error to allow retry
                        manager.teardownTap() // Clean up before retrying
                        manager.setupSystemRecording()
                    }
                }
            } else if let recorder = manager.recorder {
                RecordingView(recorder: recorder)
                    .onChange(of: recorder.isRecording) { oldValue, newValue in
                        if oldValue, !newValue { // Was recording, now is not
                            manager.createRecorder() // Create a new recorder for the next recording
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label("No Recorder", systemImage: "mic.slash")
                } description: {
                    Text("Audio recorder is not available. It might be setting up or an error occurred.")
                } actions: {
                    Button("Attempt Setup") {
                        manager.setupSystemRecording()
                    }
                }
            }
        }
        .onAppear {
            // Manager's init calls setupSystemRecording, so it's automatically handled.
            // If there was an error, the view will show the error message and retry button.
            // If successful, it will show the recorder.
            // If recorder is somehow nil without an error, it shows "No Recorder"
        }
        .onDisappear {
            manager.teardownTap()
        }
    }
}
