import Foundation
import SwiftUI

// MARK: - ArkStatus

enum ArkStatus: String, Equatable {
    case notStarted
    case inProgress
    case done

    init(from apiValue: String) {
        switch apiValue {
        case "done": self = .done
        case "in_progress": self = .inProgress
        default: self = .notStarted
        }
    }
}

// MARK: - SessionViewModel

@Observable
@MainActor
final class SessionViewModel {
    // Identity
    let sessionId: String
    let sessionName: String

    // Frozen after init
    let assignments: [ParsedAssignment]

    // Mutable state
    var currentAssignmentIndex: Int
    var currentStreak: Int
    var statusByAssignment: [String: ArkStatus]
    var latestScanId: [String: String]
    var feedbackSummary: [String: String]
    var teacherComments: [String: String]  // Always empty in Pakke 2a

    // MARK: - Computed

    var completedCount: Int {
        statusByAssignment.values.filter { $0 == .done }.count
    }

    var currentAssignment: ParsedAssignment {
        guard currentAssignmentIndex < assignments.count else {
            return assignments.last!
        }
        return assignments[currentAssignmentIndex]
    }

    var totalAssignments: Int { assignments.count }

    var isSetComplete: Bool {
        completedCount == assignments.count
    }

    // MARK: - Mutations

    func goToAssignment(_ index: Int) {
        guard index >= 0, index < assignments.count else { return }
        currentAssignmentIndex = index
    }

    func markCompleted(_ assignmentId: String, feedback: String?) {
        statusByAssignment[assignmentId] = .done
        if let feedback {
            feedbackSummary[assignmentId] = feedback
        }
    }

    func recordScan(_ scanId: String, forAssignment assignmentId: String) {
        latestScanId[assignmentId] = scanId
        if statusByAssignment[assignmentId] != .done {
            statusByAssignment[assignmentId] = .inProgress
        }
    }

    // MARK: - Init from API response

    init(from response: SessionDetailResponse) {
        self.sessionId = response.sessionId
        self.sessionName = response.sessionName
        self.assignments = response.assignments.map { ark in
            ParsedAssignment(
                id: ark.id,
                localId: ark.localId,
                text: ark.text,
                type: ark.type,
                topic: ark.topic,
                difficultyEstimate: ark.difficultyEstimate,
                positionOnPage: ""
            )
        }
        self.currentAssignmentIndex = response.currentAssignmentIndex
        self.currentStreak = response.streak?.currentStreak ?? 0

        var status: [String: ArkStatus] = [:]
        var scans: [String: String] = [:]
        var feedback: [String: String] = [:]
        var comments: [String: String] = [:]

        for ark in response.assignments {
            status[ark.id] = ArkStatus(from: ark.arkStatus)
            if let scanId = ark.latestScanId {
                scans[ark.id] = scanId
            }
            if let summary = ark.latestAiFeedbackSummary {
                feedback[ark.id] = summary
            }
            if let comment = ark.teacherComment {
                comments[ark.id] = comment
            }
        }

        self.statusByAssignment = status
        self.latestScanId = scans
        self.feedbackSummary = feedback
        self.teacherComments = comments
    }
}
