# AudioCapService Integration Guide

## Overview

AudioCapService is a standalone Swift service that provides dual audio recording capabilities (system audio + microphone) for macOS applications. Any Swift app can integrate this service to record audio from system processes and microphone simultaneously.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Your App      │────│  AudioCapService │────│  Core Audio     │
│                 │    │                  │    │  System         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                       ┌──────────────────┐
                       │  AVFoundation    │
                       │  (Microphone)    │
                       └──────────────────┘
```

## Quick Integration

### 1. Copy Required Files to Your Project

Copy these files from AudioCap to your Swift project:

```
AudioCapService.swift              # Main service class
ProcessTap/
├── AudioProcessController.swift   # Audio process detection
├── ProcessTap.swift              # System audio recording
├── CoreAudioUtils.swift          # Core Audio utilities
└── AudioRecordingPermission.swift # Permission handling
```

### 2. Add Required Frameworks

Add to your `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app records microphone audio for [your purpose]</string>
```

Add to your project's frameworks:
- `AudioToolbox.framework`
- `AVFoundation.framework`
- `OSLog.framework`

### 3. Basic Usage Example

```swift
import SwiftUI

struct MyRecordingView: View {
    @State private var audioService = AudioCapService()
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            if let process = audioService.getCurrentActiveProcess() {
                Text("Ready to record: \(process.name)")
                
                Button(audioService.isRecording ? "Stop Recording" : "Start Recording") {
                    if audioService.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
            } else {
                Text("Waiting for audio to play...")
            }
        }
    }
    
    private func startRecording() {
        guard let process = audioService.getCurrentActiveProcess() else { return }
        
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let systemURL = getDocumentsDirectory().appendingPathComponent("\(process.name)-system-\(timestamp).wav")
        let micURL = getDocumentsDirectory().appendingPathComponent("\(process.name)-mic-\(timestamp).wav")
        
        do {
            try audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioService.stopRecording()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
```

## API Reference

### AudioCapService Class

#### Properties

```swift
@MainActor @Observable
final class AudioCapService {
    // Current recording state
    private(set) var isRecording: Bool
    
    // Currently active audio process
    private(set) var activeProcess: AudioProcess?
    
    // Error message if something goes wrong
    private(set) var errorMessage: String?
}
```

#### Methods

```swift
// Start dual recording
func startRecording(systemAudioURL: URL, microphoneURL: URL) throws

// Stop recording
func stopRecording()

// Get current active audio process
func getCurrentActiveProcess() -> AudioProcess?

// Check if any audio is playing
func isAnyAudioPlaying() -> Bool
```

#### Error Types

```swift
enum AudioCapServiceError: LocalizedError {
    case noActiveProcess        // No audio-playing app found
    case tapSetupFailed        // System audio setup failed
    case microphoneSetupFailed // Microphone setup failed
}
```

## Advanced Integration Examples

### 1. SwiftUI with State Management

```swift
import SwiftUI
import Combine

class RecordingManager: ObservableObject {
    @Published private(set) var recordings: [Recording] = []
    private let audioService = AudioCapService()
    private var currentSession: RecordingSession?
    
    struct RecordingSession {
        let systemURL: URL
        let microphoneURL: URL
        let startTime: Date
        let processName: String
    }
    
    struct Recording {
        let id = UUID()
        let systemAudioURL: URL
        let microphoneURL: URL
        let processName: String
        let duration: TimeInterval
        let createdAt: Date
    }
    
    func startRecording() throws {
        guard let process = audioService.getCurrentActiveProcess() else {
            throw AudioCapServiceError.noActiveProcess
        }
        
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let systemURL = getRecordingsDirectory().appendingPathComponent("system-\(timestamp).wav")
        let micURL = getRecordingsDirectory().appendingPathComponent("mic-\(timestamp).wav")
        
        try audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
        
        currentSession = RecordingSession(
            systemURL: systemURL,
            microphoneURL: micURL,
            startTime: Date(),
            processName: process.name
        )
    }
    
    func stopRecording() {
        guard let session = currentSession else { return }
        
        audioService.stopRecording()
        
        let recording = Recording(
            systemAudioURL: session.systemURL,
            microphoneURL: session.microphoneURL,
            processName: session.processName,
            duration: Date().timeIntervalSince(session.startTime),
            createdAt: session.startTime
        )
        
        recordings.append(recording)
        currentSession = nil
    }
    
    private func getRecordingsDirectory() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let recordingsURL = urls[0].appendingPathComponent("Recordings")
        
        if !FileManager.default.fileExists(atPath: recordingsURL.path) {
            try? FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        }
        
        return recordingsURL
    }
}

struct RecordingApp: View {
    @StateObject private var recordingManager = RecordingManager()
    
    var body: some View {
        NavigationView {
            VStack {
                // Recording controls
                RecordingControlsView(manager: recordingManager)
                
                // Recordings list
                List(recordingManager.recordings) { recording in
                    RecordingRowView(recording: recording)
                }
            }
            .navigationTitle("My Audio Recorder")
        }
    }
}
```

### 2. Command Line Tool Integration

```swift
import Foundation

class CLIRecorder {
    private let audioService = AudioCapService()
    private var isRunning = false
    
    func run() async {
        print("Audio Recorder CLI - Waiting for audio...")
        isRunning = true
        
        while isRunning {
            if let process = audioService.getCurrentActiveProcess() {
                print("Found audio from: \(process.name)")
                print("Press Enter to start recording, 'q' to quit...")
                
                let input = readLine() ?? ""
                if input.lowercased() == "q" {
                    isRunning = false
                    break
                }
                
                await startRecordingSession(process: process)
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    @MainActor
    private func startRecordingSession(process: AudioProcess) async {
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let systemURL = getOutputDirectory().appendingPathComponent("\(process.name)-system-\(timestamp).wav")
        let micURL = getOutputDirectory().appendingPathComponent("\(process.name)-mic-\(timestamp).wav")
        
        do {
            try audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
            print("🔴 Recording started... Press Enter to stop")
            
            _ = readLine()
            
            audioService.stopRecording()
            print("⏹️ Recording stopped")
            print("System audio: \(systemURL.path)")
            print("Microphone: \(micURL.path)")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }
    
    private func getOutputDirectory() -> URL {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let outputURL = homeURL.appendingPathComponent("AudioRecordings")
        
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }
        
        return outputURL
    }
}

// Usage
@main
struct AudioRecorderCLI {
    static func main() async {
        let recorder = CLIRecorder()
        await recorder.run()
    }
}
```

### 3. Background Service Integration

```swift
import Foundation
import ServiceManagement

class BackgroundAudioService {
    private let audioService = AudioCapService()
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkForAudioActivity()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    @MainActor
    private func checkForAudioActivity() {
        guard !audioService.isRecording else { return }
        
        if let process = audioService.getCurrentActiveProcess() {
            // Auto-start recording for specific apps
            if shouldAutoRecord(process: process) {
                startAutoRecording(process: process)
            }
        }
    }
    
    private func shouldAutoRecord(process: AudioProcess) -> Bool {
        let autoRecordApps = ["Zoom", "Microsoft Teams", "Skype", "Discord"]
        return autoRecordApps.contains(process.name)
    }
    
    @MainActor
    private func startAutoRecording(process: AudioProcess) {
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let outputDir = getAutoRecordingsDirectory()
        let systemURL = outputDir.appendingPathComponent("\(process.name)-auto-system-\(timestamp).wav")
        let micURL = outputDir.appendingPathComponent("\(process.name)-auto-mic-\(timestamp).wav")
        
        do {
            try audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
            
            // Auto-stop after 30 minutes or when audio stops
            DispatchQueue.main.asyncAfter(deadline: .now() + 1800) { // 30 minutes
                if self.audioService.isRecording {
                    self.audioService.stopRecording()
                }
            }
            
        } catch {
            print("Auto-recording failed: \(error)")
        }
    }
    
    private func getAutoRecordingsDirectory() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let autoRecordingsURL = urls[0].appendingPathComponent("AutoRecordings")
        
        if !FileManager.default.fileExists(atPath: autoRecordingsURL.path) {
            try? FileManager.default.createDirectory(at: autoRecordingsURL, withIntermediateDirectories: true)
        }
        
        return autoRecordingsURL
    }
}
```

## Best Practices

### 1. Permission Handling

```swift
// Always check permissions before recording
func checkPermissions() async -> Bool {
    // System audio permission is handled by AudioRecordingPermission class
    let systemPermission = AudioRecordingPermission()
    
    // For microphone, request permission
    return await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }
}
```

### 2. File Management

```swift
// Create organized directory structure
func setupRecordingsDirectory() -> URL {
    let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let recordingsURL = baseURL.appendingPathComponent("AudioRecordings")
    
    // Create subdirectories by date
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayURL = recordingsURL.appendingPathComponent(dateFormatter.string(from: Date()))
    
    try? FileManager.default.createDirectory(at: todayURL, withIntermediateDirectories: true)
    return todayURL
}
```

### 3. Error Handling

```swift
// Robust error handling
func handleRecordingError(_ error: Error) {
    if let audioError = error as? AudioCapServiceError {
        switch audioError {
        case .noActiveProcess:
            showAlert("No audio playing. Please start an application that plays audio.")
        case .tapSetupFailed:
            showAlert("Failed to setup system audio recording. Check permissions.")
        case .microphoneSetupFailed:
            showAlert("Microphone access denied. Please enable in System Preferences.")
        }
    } else {
        showAlert("Recording failed: \(error.localizedDescription)")
    }
}
```

## Integration Checklist

- [ ] Copy required files to your project
- [ ] Add necessary frameworks and permissions
- [ ] Handle audio recording permissions
- [ ] Implement file management for recordings  
- [ ] Add error handling for recording failures
- [ ] Test with different audio applications
- [ ] Verify both system audio and microphone recording work
- [ ] Test permission requests on first launch
- [ ] Validate file outputs are created correctly

## File Output Format

The service creates two separate audio files:

- **System Audio**: `appname-system-timestamp.wav`
  - Contains audio from the selected application
  - Uses ProcessTap technology
  - High quality PCM format

- **Microphone**: `appname-mic-timestamp.wav`  
  - Contains microphone input
  - Uses AVAudioRecorder
  - Configurable quality settings

Both files are synchronized and can be mixed or processed separately as needed by your application.

## Support

For issues or questions about integrating AudioCapService:

1. Check that all required files are copied to your project
2. Verify framework dependencies are properly linked
3. Ensure proper permissions are requested in Info.plist
4. Test with a simple audio source first (like Music app)

The service is designed to be plug-and-play for any Swift macOS application requiring dual audio recording capabilities.