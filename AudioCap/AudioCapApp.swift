import SwiftUI

let kAppSubsystem = "codes.rambo.AudioCap"

@main
struct AudioCapApp: App {
    var body: some Scene {
        // MenuBarExtra is the scene type for menu bar apps.
                // "AudioCap" is the tooltip text.
                // The systemImage is a placeholder icon we'll replace later.
        WindowGroup {
                    RootView()
                }
                MenuBarExtra("AudioCap", systemImage: "mic.fill") {
                    // The RootView is now the content of the menu bar's dropdown window.
                    RootView()
                        .frame(width: 350) // Give it a consistent size.
                }

    }
}
