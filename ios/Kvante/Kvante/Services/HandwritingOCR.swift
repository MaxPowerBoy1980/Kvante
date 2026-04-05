import UIKit
import Vision

/// On-device handwriting recognition using Apple Vision framework.
/// Returns recognized text from a photo of handwritten work.
enum HandwritingOCR {

    struct Result {
        let text: String
        let confidence: Float
        let isCleanNumber: Bool
    }

    /// Recognize handwriting in an image. Returns the best candidate text.
    static func recognize(imageData: Data) async -> Result {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return Result(text: "", confidence: 0, isCleanNumber: false)
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: Result(text: "", confidence: 0, isCleanNumber: false))
                    return
                }

                // Collect all recognized text lines
                var lines: [(String, Float)] = []
                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        lines.append((candidate.string, candidate.confidence))
                    }
                }

                // Find the answer: look for text after "=" sign, or take the last number
                let fullText = lines.map(\.0).joined(separator: " ")
                let avgConfidence = lines.map(\.1).reduce(0, +) / Float(max(lines.count, 1))

                let answer = extractAnswer(from: fullText)
                let isClean = isCleanNumber(answer)

                continuation.resume(returning: Result(
                    text: answer,
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
                continuation.resume(returning: Result(text: "", confidence: 0, isCleanNumber: false))
            }
        }
    }

    /// Extract the final answer from recognized text.
    /// Looks for the value after "=" or takes the last number.
    private static func extractAnswer(from text: String) -> String {
        // Look for "= answer" pattern
        if let equalsRange = text.range(of: "=") {
            let afterEquals = String(text[equalsRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !afterEquals.isEmpty {
                return afterEquals
            }
        }

        // Fallback: take the last number-like token
        let tokens = text.components(separatedBy: .whitespaces)
        if let lastNumber = tokens.last(where: { $0.first?.isNumber == true }) {
            return lastNumber
        }

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Check if the answer is a clean number (no fractions, units, or special symbols)
    private static func isCleanNumber(_ text: String) -> Bool {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        // Matches: integers, decimals, negative numbers
        return cleaned.range(of: #"^-?\d+\.?\d*$"#, options: .regularExpression) != nil
    }
}
