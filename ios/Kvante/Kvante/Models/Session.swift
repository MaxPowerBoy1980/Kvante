import Foundation
import SwiftData

@Model
final class Session: Identifiable {
    @Attribute(.unique) var id: String
    var detectedLanguage: String
    var pageContext: String
    var suggestedStart: String
    var reasoning: String
    var createdAt: Date
    var status: String  // "active", "completed"

    init(id: String, detectedLanguage: String, pageContext: String,
         suggestedStart: String, reasoning: String,
         status: String = "active") {
        self.id = id
        self.detectedLanguage = detectedLanguage
        self.pageContext = pageContext
        self.suggestedStart = suggestedStart
        self.reasoning = reasoning
        self.createdAt = Date()
        self.status = status
    }
}
