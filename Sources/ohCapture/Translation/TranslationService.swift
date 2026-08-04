import Foundation
import NaturalLanguage
import Translation

enum TranslationServiceError: LocalizedError {
    case languageNotDetected

    var errorDescription: String? {
        switch self {
        case .languageNotDetected:
            return "The source language could not be detected."
        }
    }
}

@available(macOS 26.0, *)
final class TranslationService {
    func translate(_ text: String) async throws -> String {
        guard let detectedLanguage = NLLanguageRecognizer.dominantLanguage(for: text) else {
            throw TranslationServiceError.languageNotDetected
        }

        let source = Locale.Language(identifier: detectedLanguage.rawValue)
        let targetIdentifier = detectedLanguage.rawValue.lowercased().hasPrefix("zh")
            ? "en"
            : "zh-Hans"
        let target = Locale.Language(identifier: targetIdentifier)
        let session = TranslationSession(installedSource: source, target: target)
        let response = try await session.translate(text)
        return response.targetText
    }
}
