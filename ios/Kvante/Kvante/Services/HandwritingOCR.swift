import UIKit
import Vision

/// On-device handwriting recognition using Apple Vision framework.
/// Returns full text + extracted answer from a photo of handwritten work.
enum HandwritingOCR {

    struct Result {
        let fullText: String       // Everything the student wrote: "17 + 52 = 69"
        let answer: String         // Extracted final answer: "69"
        let confidence: Float
        let isCleanNumber: Bool
    }

    /// Recognize handwriting in an image.
    static func recognize(imageData: Data) async -> Result {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return Result(fullText: "", answer: "", confidence: 0, isCleanNumber: false)
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: Result(fullText: "", answer: "", confidence: 0, isCleanNumber: false))
                    return
                }

                // Collect all recognized text lines
                var lines: [(String, Float)] = []
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        lines.append((candidate.string, candidate.confidence))
                    }
                }

                let fullText = lines.map(\.0).joined(separator: " ")
                let avgConfidence = lines.map(\.1).reduce(0, +) / Float(max(lines.count, 1))

                let answer = extractAnswer(from: fullText)
                let isClean = isCleanNumber(answer)

                continuation.resume(returning: Result(
                    fullText: fullText,
                    answer: answer,
                    confidence: avgConfidence,
                    isCleanNumber: isClean
                ))
            }

            // Configure for handwriting
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["da", "en"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: Result(fullText: "", answer: "", confidence: 0, isCleanNumber: false))
            }
        }
    }

    /// Extract the final answer from recognized text.
    private static func extractAnswer(from text: String) -> String {
        // Look for the LAST "= answer" pattern (student might write multiple lines)
        if let lastEquals = text.range(of: "=", options: .backwards) {
            let afterEquals = String(text[lastEquals.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            // Take only the first token after = (the answer, not next line)
            let firstToken = afterEquals.components(separatedBy: .whitespaces).first ?? afterEquals
            if !firstToken.isEmpty {
                return firstToken
            }
        }

        // Fallback: take the last number-like token
        let tokens = text.components(separatedBy: .whitespaces)
        if let lastNumber = tokens.last(where: { $0.first?.isNumber == true }) {
            return lastNumber
        }

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Check if the answer is a clean number
    private static func isCleanNumber(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        return cleaned.range(of: #"^-?\d+\.?\d*$"#, options: .regularExpression) != nil
    }
}
