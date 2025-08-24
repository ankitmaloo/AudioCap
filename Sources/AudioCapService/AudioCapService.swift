import Foundation
import AVFoundation
import AudioToolbox
import OSLog

/// A service that provides dual audio recording capabilities (system audio + microphone)
/// Can be used by any interface to record audio from system processes and microphone simultaneously
@MainActor
@Observable
final class AudioCapService {
    
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioCapService.self))
    
    // MARK: - Public Properties
    
    /// Whether the service is currently recording
    private(set) var isRecording = false
    
    /// Current active process being recorded (for system audio)
    private(set) var activeProcess: AudioProcess?
    
    /// Error message if something goes wrong
    private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let processController = AudioProcessController()
    private var systemAudioRecorder: ProcessTapRecorder?
    private var microphoneRecorder: AVAudioRecorder?
    private var tap: ProcessTap?
    
    // MARK: - Initialization
    
    init() {
        processController.activate()
    }
    
    // MARK: - Public API
    
    /// Start recording both system audio and microphone to separate files
    /// - Parameters:
    ///   - systemAudioURL: URL where system audio will be saved
    ///   - microphoneURL: URL where microphone audio will be saved
    /// - Returns: True if recording started successfully
    func startRecording(systemAudioURL: URL, microphoneURL: URL) throws {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }
        
        guard let activeProcess = processController.activeProcess else {
            throw AudioCapServiceError.noActiveProcess
        }
        
        errorMessage = nil
        
        // Setup system audio recording
        try setupSystemAudioRecording(process: activeProcess, fileURL: systemAudioURL)
        
        // Setup microphone recording
        try setupMicrophoneRecording(fileURL: microphoneURL)
        
        // Start both recordings
        try systemAudioRecorder?.start()
        _ = microphoneRecorder?.record()
        
        processController.isRecording = true
        isRecording = true
        self.activeProcess = activeProcess
        
        logger.info("Started dual recording for process: \(activeProcess.name)")
    }
    
    /// Stop recording both tracks
    func stopRecording() {
        guard isRecording else { return }
        
        logger.info("Stopping dual recording")
        
        // Stop system audio recording
        systemAudioRecorder?.stop()
        systemAudioRecorder = nil
        
        // Stop microphone recording
        microphoneRecorder?.stop()
        microphoneRecorder = nil
        
        // Cleanup tap
        tap?.invalidate()
        tap = nil
        
        processController.isRecording = false
        isRecording = false
        activeProcess = nil
    }
    
    /// Get the current active audio process
    func getCurrentActiveProcess() -> AudioProcess? {
        return processController.activeProcess
    }
    
    /// Check if there's any audio playing
    func isAnyAudioPlaying() -> Bool {
        return processController.isAnyAudioPlaying
    }
    
    // MARK: - Private Methods
    
    private func setupSystemAudioRecording(process: AudioProcess, fileURL: URL) throws {
        let newTap = ProcessTap(process: process)
        self.tap = newTap
        newTap.activate()
        
        guard let tap = self.tap else {
            throw AudioCapServiceError.tapSetupFailed
        }
        
        let recorder = ProcessTapRecorder(fileURL: fileURL, tap: tap)
        self.systemAudioRecorder = recorder
    }
    
    private func setupMicrophoneRecording(fileURL: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.prepareToRecord()
        
        self.microphoneRecorder = recorder
    }
}

// MARK: - Error Types

enum AudioCapServiceError: LocalizedError {
    case noActiveProcess
    case tapSetupFailed
    case microphoneSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .noActiveProcess:
            return "No active audio process found. Please start playing audio from an application."
        case .tapSetupFailed:
            return "Failed to setup system audio recording tap."
        case .microphoneSetupFailed:
            return "Failed to setup microphone recording."
        }
    }
}

// MARK: - Recording Result

struct AudioCapRecordingResult {
    let systemAudioURL: URL
    let microphoneURL: URL
    let process: AudioProcess
    let startTime: Date
    let endTime: Date
}