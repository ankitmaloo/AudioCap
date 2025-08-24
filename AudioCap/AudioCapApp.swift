import SwiftUI

let kAppSubsystem = "codes.rambo.AudioCap"

@main
struct AudioCapApp: App {
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @State private var showingAPIKeyInput = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    if geminiAPIKey.isEmpty {
                        showingAPIKeyInput = true
                    }
                }
                .sheet(isPresented: $showingAPIKeyInput) {
                    APIKeyInputView()
                }
        }
    }
}
