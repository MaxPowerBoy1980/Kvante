import Foundation
import SwiftData

@Model
final class StudentProfile {
    @Attribute(.unique) var id: String
    var name: String
    var avatarName: String
    var gradeLevel: Int
    var backendStudentId: String?
    var createdAt: Date

    init(name: String, avatarName: String, gradeLevel: Int) {
        self.id = UUID().uuidString
        self.name = name
        self.avatarName = avatarName
        self.gradeLevel = gradeLevel
        self.createdAt = Date()
    }
}
