import SwiftUI

/// Data model for one week in the notebook.
struct NotebookWeek: Identifiable {
    /// Unique ID combining year and week number.
    var id: String { "\(year)-W\(weekNumber)" }
    let weekNumber: Int
    let year: Int
    let dateRange: String
    let weeklySessionIds: [String]
    let practiceSessionIds: [String]
    var solvedCount: Int
    var totalCount: Int
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

/// Manages notebook data: loads sessions, groups by week, caches detail responses.
@Observable
@MainActor
final class NotebookViewModel {
    var weeks: [NotebookWeek] = []
    var totalSolved: Int = 0
    var totalWeeks: Int { weeks.count }
    var isLoading = false

    /// Cache of loaded session details keyed by session ID.
    private var detailCache: [String: SessionDetailResponse] = [:]
    /// Formatted date strings per session, populated during loadSessions().
    private var sessionDateStrings: [String: String] = [:]

    private let apiClient: APIClient
    private let studentId: String

    init(apiClient: APIClient, studentId: String) {
        self.apiClient = apiClient
        self.studentId = studentId
    }

    // MARK: - Load session list and group by week

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        guard let history = try? await apiClient.getSessionHistory(studentId: studentId, limit: 0) else {
            return
        }

        let calendar = Calendar(identifier: .iso8601)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        // Group sessions by ISO week
        var weekMap: [String: (weekNumber: Int, year: Int, weekly: [SessionSummary], practice: [SessionSummary])] = [:]

        for session in history.sessions {
            guard let date = isoFormatter.date(from: session.createdAt) else { continue }
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let year = comps.yearForWeekOfYear, let week = comps.weekOfYear else { continue }
            let key = "\(year)-W\(week)"

            if weekMap[key] == nil {
                weekMap[key] = (weekNumber: week, year: year, weekly: [], practice: [])
            }

            if session.mode == "practice" {
                weekMap[key]!.practice.append(session)
            } else {
                weekMap[key]!.weekly.append(session)
            }
        }

        // Build date strings per session and sorted weeks
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "da_DK")
        dateFormatter.dateFormat = "d. MMM"

        // Cache formatted dates for each session
        for session in history.sessions {
            if let date = isoFormatter.date(from: session.createdAt) {
                sessionDateStrings[session.sessionId] = dateFormatter.string(from: date)
            }
        }

        var allWeeks: [NotebookWeek] = []
        for (_, value) in weekMap {
            let allSessions = value.weekly + value.practice
            let dateRange = Self.computeDateRange(
                year: value.year,
                week: value.weekNumber,
                calendar: calendar,
                formatter: dateFormatter
            )
            let solved = allSessions.reduce(0) { $0 + $1.completedCount }
            let total = allSessions.reduce(0) { $0 + $1.assignmentCount }

            allWeeks.append(NotebookWeek(
                weekNumber: value.weekNumber,
                year: value.year,
                dateRange: dateRange,
                weeklySessionIds: value.weekly.map(\.sessionId),
                practiceSessionIds: value.practice.map(\.sessionId),
                solvedCount: solved,
                totalCount: total
            ))
        }

        allWeeks.sort { a, b in
            if a.year != b.year { return a.year > b.year }
            return a.weekNumber > b.weekNumber
        }

        weeks = allWeeks
        totalSolved = history.sessions.reduce(0) { $0 + $1.completedCount }
    }

    // MARK: - Lazy-load session details for a week

    /// Returns session groups for a week, loading details on demand.
    func sessionGroups(for week: NotebookWeek) async -> (weekly: [NotebookSessionGroup], practice: [NotebookSessionGroup]) {
        let weeklyGroups = await loadSessionGroups(sessionIds: week.weeklySessionIds, weekNumber: week.weekNumber)
        let practiceGroups = await loadSessionGroups(sessionIds: week.practiceSessionIds, weekNumber: week.weekNumber)
        return (weekly: weeklyGroups, practice: practiceGroups)
    }

    private func loadSessionGroups(sessionIds: [String], weekNumber: Int) async -> [NotebookSessionGroup] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "da_DK")
        dateFormatter.dateFormat = "d. MMM"
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

        var groups: [NotebookSessionGroup] = []
        for sessionId in sessionIds {
            let detail = await loadDetail(sessionId: sessionId)
            guard let detail else { continue }

            let assignments = detail.assignments.map { a in
                NotebookAssignment(
                    id: a.id,
                    text: a.text,
                    arkStatus: a.arkStatus,
                    correctAnswer: a.correctAnswer,
                    studentAnswer: a.studentAnswer,
                    feedbackSummary: a.latestAiFeedbackSummary,
                    scanId: a.latestScanId,
                    position: a.position,
                    weekNumber: weekNumber
                )
            }.sorted { $0.position < $1.position }

            let solved = assignments.filter { $0.arkStatus == "done" }.count
            let sessionName = detail.sessionName.isEmpty ? "Øvelse" : detail.sessionName

            // Find a date string from the session summary (stored during loadSessions)
            let dateString = sessionDateStrings[sessionId] ?? ""

            groups.append(NotebookSessionGroup(
                id: sessionId,
                name: sessionName,
                date: dateString,
                solvedCount: solved,
                totalCount: assignments.count,
                assignments: assignments
            ))
        }
        return groups
    }

    private func loadDetail(sessionId: String) async -> SessionDetailResponse? {
        if let cached = detailCache[sessionId] {
            return cached
        }
        guard let detail = try? await apiClient.getSession(sessionId: sessionId) else {
            return nil
        }
        detailCache[sessionId] = detail
        return detail
    }

    // MARK: - Helpers

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
