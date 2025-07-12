import Foundation

struct Gemini {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func transcribe(audioURL: URL) async throws -> String {
        // This is a placeholder for the actual transcription implementation.
        // In a real application, you would use a library like GoogleAI for Swift
        // or make a network request to the Gemini API.
        print("Transcribing audio at: \(audioURL.path)")
        try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network request
        return "This is a sample transcription of the recorded audio. It includes a TODO to buy milk."
    }

    func extractTodos(from text: String) async throws -> [String] {
        // This is a placeholder for the actual TODO extraction implementation.
        print("Extracting TODOs from: \(text)")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network request
        let todos = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.uppercased().hasPrefix("TODO") }
        return todos
    }
}