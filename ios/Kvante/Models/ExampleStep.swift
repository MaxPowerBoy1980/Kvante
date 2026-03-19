import Foundation

struct ExampleStep: Identifiable, Codable {
    var id: Int { step }
    let step: Int
    let instruction: String
    let visual: String
    let explanation: String
}
