import Foundation

// MARK: - Visual Instruction

/// Decoded from the flat JSON visual object. `type` and `action` are always present.
/// All other fields are type-specific and decoded into `params`.
struct VisualInstruction: Codable {
    let type: String
    let action: String
    let params: [String: AnyCodable]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        type = try container.decode(String.self, forKey: DynamicCodingKey(stringValue: "type")!)
        action = try container.decode(String.self, forKey: DynamicCodingKey(stringValue: "action")!)

        var extracted: [String: AnyCodable] = [:]
        for key in container.allKeys where key.stringValue != "type" && key.stringValue != "action" {
            // Bool MUST come before Int — JSON true/false can decode as Int in Swift
            if let boolVal = try? container.decode(Bool.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(boolVal)
            } else if let intVal = try? container.decode(Int.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(intVal)
            } else if let doubleVal = try? container.decode(Double.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(doubleVal)
            } else if let stringVal = try? container.decode(String.self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(stringVal)
            } else if let arrayVal = try? container.decode([AnyCodable].self, forKey: key) {
                extracted[key.stringValue] = AnyCodable(arrayVal)
            }
        }
        params = extracted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encode(type, forKey: DynamicCodingKey(stringValue: "type")!)
        try container.encode(action, forKey: DynamicCodingKey(stringValue: "action")!)
        for (key, value) in params {
            if let codingKey = DynamicCodingKey(stringValue: key) {
                try container.encode(value, forKey: codingKey)
            }
        }
    }

    // MARK: - Typed accessors

    func intParam(_ key: String) -> Int? {
        params[key]?.value as? Int
    }

    func stringParam(_ key: String) -> String? {
        params[key]?.value as? String
    }

    func stringArrayParam(_ key: String) -> [String]? {
        if let arr = params[key]?.value as? [AnyCodable] {
            return arr.compactMap { $0.value as? String }
        }
        return nil
    }

    func intArrayParam(_ key: String) -> [Int]? {
        if let arr = params[key]?.value as? [AnyCodable] {
            return arr.compactMap { $0.value as? Int }
        }
        return nil
    }
}

// MARK: - Animation Step

struct AnimationStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let phase: String
    let text: String
    let visual: VisualInstruction
    let audioCue: String

    enum CodingKeys: String, CodingKey {
        case step, phase, text, visual
        case audioCue = "audio_cue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(Int.self, forKey: .step)
        phase = try container.decode(String.self, forKey: .phase)
        text = try container.decode(String.self, forKey: .text)
        visual = try container.decode(VisualInstruction.self, forKey: .visual)
        audioCue = try container.decodeIfPresent(String.self, forKey: .audioCue) ?? ""
    }
}

// MARK: - Helpers

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

/// Type-erased Codable wrapper for heterogeneous JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool MUST come before Int — JSON true/false can decode as Int(1/0) in Swift
        if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let bool = value as? Bool { try container.encode(bool) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let string = value as? String { try container.encode(string) }
        else if let array = value as? [AnyCodable] { try container.encode(array) }
    }
}
