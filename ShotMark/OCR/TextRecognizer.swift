import CoreGraphics
import Vision

/// On-device OCR with Apple's Vision framework (no network, no extra dependency).
enum TextRecognizer {
    static func recognizeText(in image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.recognitionLanguages = ["fr-FR", "en-US", "de-DE", "es-ES", "it-IT"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            let observations = request.results ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}
