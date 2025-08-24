# AudioCapService - Quick Integration Example

## Minimal Integration for Any Swift App

### 1. Files to Copy

Copy these 5 files from AudioCap to your project:

```
YourApp/
├── AudioCapService/
│   ├── AudioCapService.swift           # Main service class
│   ├── AudioProcessController.swift    # Process detection
│   ├── ProcessTap.swift               # System audio capture
│   ├── CoreAudioUtils.swift           # Audio utilities  
│   └── AudioRecordingPermission.swift # Permissions
└── YourAppViews/
    └── RecordingView.swift            # Your UI
```

### 2. Add to Info.plist

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio</string>
```

### 3. Minimal Working Example

Create `RecordingView.swift`:

```swift
import SwiftUI

struct RecordingView: View {
    @State private var audioService = AudioCapService()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple Audio Recorder")
                .font(.title)
            
            if let process = audioService.getCurrentActiveProcess() {
                VStack {
                    Text("🎵 Detected: \(process.name)")
                        .font(.headline)
                    
                    Button(audioService.isRecording ? "⏹️ Stop" : "🔴 Record") {
                        if audioService.isRecording {
                            audioService.stopRecording()
                        } else {
                            startRecording()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Text("🎧 Play some audio to begin...")
                    .foregroundColor(.secondary)
            }
            
            if audioService.isRecording {
                Text("🔴 Recording...")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
    
    private func startRecording() {
        guard let process = audioService.getCurrentActiveProcess() else { return }
        
        // Create file URLs
        let timestamp = Int(Date.now.timeIntervalSinceReferenceDate)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let systemURL = documentsURL.appendingPathComponent("\(process.name)-system-\(timestamp).wav")
        let micURL = documentsURL.appendingPathComponent("\(process.name)-mic-\(timestamp).wav")
        
        // Start recording
        do {
            try audioService.startRecording(systemAudioURL: systemURL, microphoneURL: micURL)
            print("✅ Recording started")
            print("System: \(systemURL.path)")
            print("Mic: \(micURL.path)")
        } catch {
            print("❌ Recording failed: \(error)")
        }
    }
}

// App entry point
@main
struct MyAudioApp: App {
    var body: some Scene {
        WindowGroup {
            RecordingView()
        }
    }
}
```

### 4. That's It! 

Your app now has dual audio recording with just:
- **5 copied files** 
- **1 Info.plist entry**
- **1 SwiftUI view**

## Test It

1. Build and run your app
2. Start playing music or a video  
3. Click "🔴 Record"
4. Click "⏹️ Stop" after a few seconds
5. Check your Documents folder for the `.wav` files

## File Output

After recording, you'll find:
```
~/Documents/
├── AppName-system-1234567890.wav  # System audio
└── AppName-mic-1234567890.wav     # Microphone
```

## Next Steps

- Add file management UI
- Implement audio playback
- Add recording list
- Integrate transcription services
- Add export/sharing features

The service handles all the complex Core Audio setup - you just provide file URLs and call start/stop!