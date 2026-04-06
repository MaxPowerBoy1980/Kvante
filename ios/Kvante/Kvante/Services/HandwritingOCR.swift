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
    /// Pass assignmentText (e.g. "Regn ud: 347 + 286") for context-aware parsing.
    static func recognize(imageData: Data, assignmentText: String = "") async -> Result {
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

                let rawLines = lines.map(\.0)
                let rawJoined = rawLines.joined(separator: " ")
                let fullText = reconstructStackedArithmetic(lines: rawLines)
                    ?? reconstructFromAssignmentContext(ocrLines: rawLines, assignmentText: assignmentText)
                    ?? reconstructFromNumbers(rawText: rawJoined)
                    ?? rawJoined
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

    /// Detect stacked arithmetic (columnar) layout from OCR lines.
    /// Input lines like ["568", "+ 275", "843"] or ["11", "568", "+ 275", "843"]
    /// Output: "568 + 275 = 843"
    private static func reconstructStackedArithmetic(lines: [String]) -> String? {
        guard lines.count >= 2 else { return nil }

        // Clean each line: trim whitespace
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }

        // Find the operator line (starts with + or -)
        var opSymbol: String?
        var operands: [String] = []
        var answerLine: String?

        for line in cleaned {
            // Skip empty lines and lines that look like horizontal rules
            if line.isEmpty || line.allSatisfy({ $0 == "-" || $0 == "_" || $0 == "—" }) {
                continue
            }

            // Line starts with operator: "+ 275" or "- 47"
            if let first = line.first, (first == "+" || first == "-" || first == "×" || first == "x") {
                let rest = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if rest.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) && !rest.isEmpty {
                    opSymbol = String(first) == "x" ? "×" : String(first)
                    operands.append(rest)
                    continue
                }
            }

            // Pure number line
            let digits = line.filter { $0.isNumber }
            if digits.count >= line.filter({ !$0.isWhitespace }).count / 2 && !digits.isEmpty {
                operands.append(digits)
            }
        }

        // Need at least 2 operands (numbers) and ideally an operator
        guard operands.count >= 2 else { return nil }
        // If no operator found, can't reconstruct
        guard let op = opSymbol else { return nil }

        // Last operand is the answer (below the line)
        answerLine = operands.removeLast()

        // If we have a small carry number before the first operand, skip it
        // e.g., ["11", "568", "275"] → "11" is the carry notation
        if operands.count > 2 {
            // Keep only the two largest numbers as operands
            operands = Array(operands.suffix(2))
        }

        guard operands.count >= 1, let answer = answerLine else { return nil }

        if operands.count == 1 {
            return "\(operands[0]) \(op) ? = \(answer)"
        }

        return "\(operands[0]) \(op) \(operands[1]) = \(answer)"
    }

    /// Use the known assignment to interpret OCR numbers.
    /// If assignment is "347 + 286" and OCR found numbers [11, 347, 286, 633],
    /// reconstruct as "347 + 286 = 633".
    private static func reconstructFromAssignmentContext(ocrLines: [String], assignmentText: String) -> String? {
        guard !assignmentText.isEmpty else { return nil }

        // Extract operator from assignment
        let op: String
        if assignmentText.contains("+") {
            op = "+"
        } else if assignmentText.contains("-") {
            op = "-"
        } else {
            return nil
        }

        // Extract numbers from assignment text
        let assignmentNumbers = assignmentText.matches(of: /\d+/).map { Int(String($0.output))! }
        guard assignmentNumbers.count >= 2 else { return nil }
        let a = assignmentNumbers[0]
        let b = assignmentNumbers[1]

        // Extract ALL numbers from OCR output (across all lines)
        let allOcrText = ocrLines.joined(separator: " ")
        let ocrNumbers = allOcrText.matches(of: /\d+/).map { Int(String($0.output))! }
        guard !ocrNumbers.isEmpty else { return nil }

        // Check if OCR found the assignment operands
        let foundA = ocrNumbers.contains(a)
        let foundB = ocrNumbers.contains(b)

        if foundA && foundB {
            // Find the answer: a number that's NOT one of the operands
            // (or the last number if all match)
            let candidates = ocrNumbers.filter { $0 != a && $0 != b }
            if let answer = candidates.last {
                return "\(a) \(op) \(b) = \(answer)"
            }
            // If no candidate (e.g., operand repeated), use last OCR number
            if let last = ocrNumbers.last, last != a || last != b {
                return "\(a) \(op) \(b) = \(last)"
            }
        }

        // Partial match: if we find at least one operand + an answer-like number
        if let lastNum = ocrNumbers.last, (foundA || foundB) {
            return "\(a) \(op) \(b) = \(lastNum)"
        }

        return nil
    }

    /// Last resort: extract numbers and operator from raw OCR text.
    /// "+ / 347 286 633" → "347 + 286 = 633"
    private static func reconstructFromNumbers(rawText: String) -> String? {
        // Find all numbers (2+ digits)
        let allNumbers = rawText.matches(of: /\d{2,}/).map { String($0.output) }
        guard allNumbers.count >= 3 else { return nil }

        // Detect operator anywhere in the text
        let op: String
        if rawText.contains("+") {
            op = "+"
        } else if rawText.contains("-") || rawText.contains("—") {
            op = "-"
        } else {
            return nil
        }

        // Use the last 3 numbers: operand, operand, answer
        // This skips carry notation (e.g., "11" before "347")
        let last3 = Array(allNumbers.suffix(3))
        return "\(last3[0]) \(op) \(last3[1]) = \(last3[2])"
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
