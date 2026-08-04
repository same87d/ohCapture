import CoreGraphics
import Vision

enum OCRServiceError: LocalizedError {
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return "No text was found in the captured image."
        }
    }
}

final class OCRService {
    func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true

                do {
                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])

                    let observations = (request.results ?? []).sorted { left, right in
                        let verticalDifference = abs(left.boundingBox.midY - right.boundingBox.midY)
                        if verticalDifference > 0.02 {
                            return left.boundingBox.midY > right.boundingBox.midY
                        }
                        return left.boundingBox.minX < right.boundingBox.minX
                    }
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    let text = lines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    guard !text.isEmpty else {
                        throw OCRServiceError.noTextFound
                    }
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
