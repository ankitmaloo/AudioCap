# AudioCapService Swift Package

A ready-to-use Swift Package for dual audio recording on macOS - capture system audio and microphone simultaneously.

## 🚀 **Why Use the Package Instead of Copying Files?**

### Before (Manual Integration):
❌ Copy 5 files to your project  
❌ Setup build dependencies manually  
❌ Handle framework linking  
❌ Manage updates manually  

### After (Swift Package):
✅ One-line import: `import AudioCapService`  
✅ Automatic dependency management  
✅ Easy updates via package manager  
✅ No file copying needed  

## Installation

### Method 1: Xcode (Easiest)
1. Open your Xcode project
2. **File → Add Package Dependencies**
3. Enter repository URL (when published)
4. Click **Add Package**

### Method 2: Package.swift
```swift
dependencies: [
    .package(path: "/path/to/AudioCapService", from: "1.0.0")
]
```

## Ultra-Simple Usage

```swift
import SwiftUI
import AudioCapService  // 👈 Just one import!

struct MyRecordingView: View {
    @State private var audioService = AudioCapService()
    
    var body: some View {
        VStack {
            if let process = audioService.getCurrentActiveProcess() {
                Text("🎵 \(process.name)")
                
                Button(audioService.isRecording ? "⏹️ Stop" : "🔴 Record") {
                    toggleRecording()
                }
            } else {
                Text("🎧 Play some audio...")
            }
        }
    }
    
    func toggleRecording() {
        if audioService.isRecording {
            audioService.stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        guard let process = audioService.getCurrentActiveProcess() else { return }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        
        let systemURL = docs.appendingPathComponent("\(process.name)-system-\(timestamp).wav")
        let micURL = docs.appendingPathComponent("\(process.name)-mic-\(timestamp).wav")
        
        try? audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
    }
}
```

## What You Get

- **🎧 Dual Recording**: System audio + microphone to separate files
- **🔍 Auto Detection**: Finds audio-playing apps automatically
- **🛡️ Permission Handling**: Built-in audio recording permissions
- **⚡ High Performance**: Uses Core Audio ProcessTap technology
- **🎯 Simple API**: Just start/stop with file URLs
- **🔧 SwiftUI Ready**: @Observable support built-in

## Files Created

```bash
YourDocuments/
├── AppName-system-1234567890.wav  # System audio
└── AppName-mic-1234567890.wav     # Microphone audio
```

## Requirements

- macOS 14.0+
- Swift 5.9+

## Permissions Required

Add to your `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Record microphone for audio capture</string>
```

## API Overview

```swift
// Main service class
@Observable class AudioCapService {
    var isRecording: Bool { get }
    var activeProcess: AudioProcess? { get }
    
    func startRecording(systemAudioURL: URL, microphoneURL: URL) throws
    func stopRecording()
    func getCurrentActiveProcess() -> AudioProcess?
}
```

## Integration Comparison

| Method | Setup Time | Maintenance | Updates |
|--------|------------|-------------|---------|
| **Copy Files** | 15 minutes | Manual | Manual file replacement |
| **Swift Package** | 2 minutes | Automatic | `swift package update` |

## Testing the Package

```bash
# Build the package
swift build

# Run tests (when added)
swift test
```

This package eliminates the need to copy files and provides a clean, maintainable way to add dual audio recording to any macOS Swift project!