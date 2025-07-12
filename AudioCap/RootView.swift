import SwiftUI

@MainActor
struct RootView: View {
    @State private var permission = AudioRecordingPermission()

    var body: some View {
        // Change Form to VStack and remove the style modifier
        VStack(spacing: 15) {
            switch permission.status {
            case .unknown:
                requestPermissionView
            case .authorized:
                recordingView
            case .denied:
                permissionDeniedView
            }
        }
        .padding() // Add some padding around the whole view
    }
    
    // The rest of the file (your @ViewBuilder properties) remains the same.
    @ViewBuilder
    private var requestPermissionView: some View {
        LabeledContent("Please Allow Audio Recording") {
            Button("Allow") {
                permission.request()
            }
        }
    }

    @ViewBuilder
    private var permissionDeniedView: some View {
        LabeledContent("Audio Recording Permission Required") {
            Button("Open System Settings") {
                NSWorkspace.shared.openSystemSettings()
            }
        }
    }

    @ViewBuilder
    private var recordingView: some View {
        TabView {
            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
            ProcessSelectionView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
        }
    }
}

// ... (NSWorkspace extension remains the same) ...
extension NSWorkspace {
    func openSystemSettings() {
        guard let url = urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else {
            assertionFailure("Failed to get System Settings app URL")
            return
        }

        openApplication(at: url, configuration: .init())
    }
}

#if DEBUG
#Preview {
    RootView()
}
#endif
