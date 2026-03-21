import Foundation
import SwiftData

@Model
final class Submission: Identifiable {
    @Attribute(.unique) var id: String
    var sessionId: String
    var assignmentId: String
    var attemptNumber: Int
    var methodologySound: Bool
    var feedbackText: String?
    var createdAt: Date

    init(id: String, sessionId: String, assignmentId: String,
         attemptNumber: Int, methodologySound: Bool,
         feedbackText: String? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.assignmentId = assignmentId
        self.attemptNumber = attemptNumber
        self.methodologySound = methodologySound
        self.feedbackText = feedbackText
        self.createdAt = Date()
    }
}
