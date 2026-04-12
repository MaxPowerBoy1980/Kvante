import SwiftUI

struct FeedbackPreviewSheet: View {
    let assignment: ParsedAssignment
    let session: SessionViewModel
    let apiClient: APIClient
    let onOpenChat: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var scanId: String? {
        session.latestScanId[assignment.id]
    }

    private var cropRegion: CropRegion? {
        session.boundingBoxByAssignment[assignment.id]
    }

    private var aiFeedback: String? {
        session.feedbackSummary[assignment.id]
    }

    private var teacherComment: String? {
        session.teacherComments[assignment.id]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header: assignment number + text
                    Text("Opgave \(assignment.localId) — \(assignment.text)")
                        .font(.headline)
                        .foregroundStyle(KvanteTheme.Colors.ink)

                    // Large scan thumbnail (full-width)
                    if let scanId {
                        ZStack {
                            ScannedImageView(
                                data: nil,
                                scanId: scanId,
                                apiClient: apiClient,
                                maxPixelSize: 800
                            )
                            .overlay {
                                if let cropRegion {
                                    BoundingBoxOverlay(region: cropRegion)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Kvante section
                    if let aiFeedback {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Kvante", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KvanteTheme.Colors.ink)

                            Text(aiFeedback)
                                .font(.body)
                                .foregroundStyle(KvanteTheme.Colors.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KvanteTheme.Colors.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Teacher section — hidden when empty (always in Pakke 2a)
                    if let teacherComment, !teacherComment.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Fra laerer", systemImage: "person.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KvanteTheme.Colors.ink)

                            Text(teacherComment)
                                .font(.body)
                                .foregroundStyle(KvanteTheme.Colors.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KvanteTheme.Colors.cream)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Open full chat button
                    Button(action: onOpenChat) {
                        Text("Abn fuld chat")
                            .font(KvanteTheme.Fonts.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
    }
}
