import SwiftUI

/// Data model for one week in the notebook.
struct NotebookWeek: Identifiable {
    /// Unique ID combining year and week number.
    var id: String { "\(year)-W\(weekNumber)" }
    let weekNumber: Int
    let year: Int
    let dateRange: String
    var solvedCount: Int
    var totalCount: Int
    /// Pre-built session groups for this week.
    let weeklyGroups: [NotebookSessionGroup]
    let practiceGroups: [NotebookSessionGroup]
}

/// A loaded assignment ready for display in a facit card.
struct NotebookAssignment: Identifiable {
    let id: String
    let text: String
    let arkStatus: String
    let correctAnswer: String?
    let studentAnswer: String?
    let feedbackSummary: String?
    let scanId: String?
    let position: Int
    let weekNumber: Int
    let gearScore: GearScore?
    let improvementTip: String?
}

/// A group of assignments belonging to one session.
struct NotebookSessionGroup: Identifiable {
    let id: String          // session ID
    let name: String        // e.g. "Ugematematik — uge 15" or "Addition (Let)"
    let date: String        // e.g. "6. apr"
    let solvedCount: Int
    let totalCount: Int
    let assignments: [NotebookAssignment]
}

/// Manages notebook data: loads all sessions with assignments in one request.
@Observable
@MainActor
final class NotebookViewModel {
    var weeks: [NotebookWeek] = []
    var totalSolved: Int = 0
    var totalWeeks: Int { weeks.count }
    var isLoading = true
    var loadError: String?

    private let apiClient: APIClient
    private let studentId: String

    init(apiClient: APIClient, studentId: String) {
        self.apiClient = apiClient
        self.studentId = studentId
    }

    // MARK: - Load everything in one request

    func loadSessions() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let history: SessionHistoryWithAssignmentsResponse
        do {
            history = try await apiClient.getSessionHistoryWithAssignments(studentId: studentId)
        } catch {
            loadError = "loadSessions failed: \(error)"
            print("[NotebookVM] loadSessions FAILED for student \(studentId): \(error)")
            return
        }
        print("[NotebookVM] loadSessions OK: \(history.sessions.count) sessions")

        let calendar = Calendar(identifier: .iso8601)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "da_DK")
        dateFormatter.dateFormat = "d. MMM"

        // Group sessions by ISO week and build groups immediately
        var weekMap: [String: (
            weekNumber: Int,
            year: Int,
            weekly: [NotebookSessionGroup],
            practice: [NotebookSessionGroup]
        )] = [:]

        for session in history.sessions {
            guard let date = isoFormatter.date(from: session.createdAt) else { continue }
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let year = comps.yearForWeekOfYear, let week = comps.weekOfYear else { continue }
            let key = "\(year)-W\(week)"

            if weekMap[key] == nil {
                weekMap[key] = (weekNumber: week, year: year, weekly: [], practice: [])
            }

            let group = buildGroup(from: session, weekNumber: week, dateFormatter: dateFormatter, isoFormatter: isoFormatter)

            if session.mode == "practice" {
                weekMap[key]!.practice.append(group)
            } else {
                weekMap[key]!.weekly.append(group)
            }
        }

        var allWeeks: [NotebookWeek] = []
        for (_, value) in weekMap {
            let allGroups = value.weekly + value.practice
            let dateRange = Self.computeDateRange(
                year: value.year,
                week: value.weekNumber,
                calendar: calendar,
                formatter: dateFormatter
            )
            let solved = allGroups.reduce(0) { $0 + $1.solvedCount }
            let total = allGroups.reduce(0) { $0 + $1.totalCount }

            allWeeks.append(NotebookWeek(
                weekNumber: value.weekNumber,
                year: value.year,
                dateRange: dateRange,
                solvedCount: solved,
                totalCount: total,
                weeklyGroups: value.weekly,
                practiceGroups: value.practice
            ))
        }

        allWeeks.sort { a, b in
            if a.year != b.year { return a.year > b.year }
            return a.weekNumber > b.weekNumber
        }

        weeks = allWeeks
        totalSolved = history.sessions.reduce(0) { $0 + $1.completedCount }
    }

    // MARK: - Synchronous group access (data already loaded)

    /// Returns pre-built session groups for a week. No async, no API calls.
    func sessionGroups(for week: NotebookWeek) -> (weekly: [NotebookSessionGroup], practice: [NotebookSessionGroup]) {
        return (weekly: week.weeklyGroups, practice: week.practiceGroups)
    }

    // MARK: - Helpers

    private func buildGroup(
        from session: SessionSummaryWithAssignments,
        weekNumber: Int,
        dateFormatter: DateFormatter,
        isoFormatter: ISO8601DateFormatter
    ) -> NotebookSessionGroup {
        let assignments = session.assignments.map { a in
            NotebookAssignment(
                id: a.id,
                text: a.text,
                arkStatus: a.arkStatus,
                correctAnswer: a.correctAnswer,
                studentAnswer: a.studentAnswer,
                feedbackSummary: a.latestAiFeedbackSummary,
                scanId: a.latestScanId,
                position: a.position,
                weekNumber: weekNumber,
                gearScore: a.gearScore,
                improvementTip: a.improvementTip
            )
        }.sorted { $0.position < $1.position }

        let solved = assignments.filter { $0.arkStatus == "done" }.count
        let sessionName = session.name.isEmpty ? "Øvelse" : session.name

        let dateString: String
        if let date = isoFormatter.date(from: session.createdAt) {
            dateString = dateFormatter.string(from: date)
        } else {
            dateString = ""
        }

        return NotebookSessionGroup(
            id: session.sessionId,
            name: sessionName,
            date: dateString,
            solvedCount: solved,
            totalCount: assignments.count,
            assignments: assignments
        )
    }

    private static func computeDateRange(year: Int, week: Int, calendar: Calendar, formatter: DateFormatter) -> String {
        var comps = DateComponents()
        comps.yearForWeekOfYear = year
        comps.weekOfYear = week
        comps.weekday = 2 // Monday
        guard let monday = calendar.date(from: comps) else { return "" }
        guard let friday = calendar.date(byAdding: .day, value: 4, to: monday) else { return "" }
        return "\(formatter.string(from: monday)) – \(formatter.string(from: friday))"
    }
}
