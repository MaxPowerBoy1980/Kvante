import Foundation
import SwiftData

@Model
final class Assignment: Identifiable {
    @Attribute(.unique) var id: String
    var sessionId: String
    var text: String
    var type: String
    var topic: String
    var difficultyEstimate: Int
    var positionOnPage: String
    var status: String  // "not_started", "in_progress", "completed"

    init(id: String, sessionId: String, text: String, type: String,
         topic: String, difficultyEstimate: Int, positionOnPage: String,
         status: String = "not_started") {
        self.id = id
        self.sessionId = sessionId
        self.text = text
        self.type = type
        self.topic = topic
        self.difficultyEstimate = difficultyEstimate
        self.positionOnPage = positionOnPage
        self.status = status
    }
}
