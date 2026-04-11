import SwiftUI

struct ErrorAnalysisSheet: View {
    let assignment: ParsedAssignment
    let studentAnswer: String
    let errorDescription: String
    let scanId: String?
    let apiClient: APIClient
    let onOpenChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Opgave \(assignment.localId)")
                .font(.headline)
                .foregroundStyle(KvanteTheme.Colors.ink)

            Text(assignment.text)
                .font(.title3.weight(.semibold))
                .foregroundStyle(KvanteTheme.Colors.ink)

            if let scanId {
                AsyncImage(url: apiClient.scanImageURL(scanId: scanId)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KvanteTheme.Colors.cream).frame(height: 120)
                        .overlay { ProgressView() }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text("Du skrev: \(studentAnswer)")
                    .font(.body.weight(.medium))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(KvanteTheme.Colors.primary)
                Text(errorDescription)
                    .font(.body).foregroundStyle(KvanteTheme.Colors.ink)
            }
            .padding(12)
            .background(KvanteTheme.Colors.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            Spacer()

            Button {
                onOpenChat()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Få hjælp i chatten")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KvanteTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
}
