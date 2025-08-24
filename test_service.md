# AudioCap Service Testing Guide

## Quick Test Steps:

### 1. Run the App
```bash
# Open in Xcode and run (Cmd+R)
open AudioCap.xcodeproj
```

### 2. Test Sequence:

1. **Launch app** - Should see permission dialog for audio recording
2. **Grant permissions** - Allow audio recording access  
3. **Play some audio** - Start music/video from any app
4. **Go to Notes tab** - Should see recording controls appear
5. **Hit Record** - Should show "Recording..." with red indicator
6. **Wait 10 seconds** - Let it record some content
7. **Hit Stop** - Should process and show transcription

### 3. Verify Files Created:
```bash
# Check recording files were created
ls -la ~/Library/Application\ Support/AudioCap/
```

Should see files like:
- `AppName-system-12345.wav` (system audio)  
- `AppName-mic-12345.wav` (microphone)
- `AppName-system-12345.wav.txt` (transcription)

### 4. Test Different Apps:
- Music app
- YouTube in browser  
- Video calls
- System sounds

## What Should Work:
- ✅ Dual recording (system + mic simultaneously)
- ✅ Automatic process detection
- ✅ Transcription via Gemini API
- ✅ Todo extraction
- ✅ Notes interface with recording controls

## Troubleshooting:

**No recording controls showing:**
- Make sure audio is actually playing
- Check permissions in System Preferences > Security & Privacy

**Recording fails:**
- Verify both microphone and system audio permissions granted
- Check Gemini API key is set

**No transcription:**
- Verify Gemini API key in app settings
- Check network connection