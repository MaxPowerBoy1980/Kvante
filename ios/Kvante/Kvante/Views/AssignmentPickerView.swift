import SwiftUI

struct AssignmentPickerView: View {
    let pageResponse: PageScanResponse
    let onSelectAssignment: (ParsedAssignment) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Page context
                if !pageResponse.pageContext.isEmpty {
                    Text(pageResponse.pageContext)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Kvante's suggestion
                if !pageResponse.suggestedStart.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(.orange)
                        Text("Jeg foreslår du starter med opgave \(pageResponse.suggestedStart)!")
                            .font(.headline)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                // Assignment cards grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(pageResponse.assignments) { assignment in
                        AssignmentCardView(
                            assignment: assignment,
                            isRecommended: assignment.localId == pageResponse.suggestedStart
                        ) {
                            onSelectAssignment(assignment)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Vælg en opgave")
    }
}
