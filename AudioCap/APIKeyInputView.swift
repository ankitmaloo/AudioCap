
import SwiftUI

struct APIKeyInputView: View {
    @AppStorage("geminiAPIKey") private var geminiAPIKey: String = ""
    @State private var inputAPIKey: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Gemini API Key")
                .font(.title)
                .padding()

            SecureField("API Key", text: $inputAPIKey)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Save API Key") {
                geminiAPIKey = inputAPIKey
                dismiss()
            }
            .controlSize(.large)
            .disabled(inputAPIKey.isEmpty)
        }
        .padding()
        .onAppear {
            inputAPIKey = geminiAPIKey // Pre-fill if already saved
        }
    }
}

struct APIKeyInputView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeyInputView()
    }
}
