import SwiftUI

/// The main notebook view — a page-style TabView with cover + week pages.
struct NotebookView: View {
    let viewModel: NotebookViewModel
    let apiClient: APIClient
    let studentName: String
    let onBack: () -> Void

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Hjem")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(KvanteTheme.Colors.ink)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                TabView(selection: $currentPage) {
                    // Page 0: Cover
                    NotebookCoverView(
                        studentName: studentName,
                        totalSolved: viewModel.totalSolved,
                        totalWeeks: viewModel.totalWeeks
                    )
                    .tag(0)

                    // Pages 1..N: Week pages (newest first)
                    ForEach(Array(viewModel.weeks.enumerated()), id: \.element.id) { index, week in
                        NotebookWeekView(
                            week: week,
                            viewModel: viewModel,
                            apiClient: apiClient,
                            pageLabel: pageLabel(index: index + 1)
                        )
                        .tag(index + 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                pageIndicator
                    .padding(.bottom, 8)
            }
        }
        .background(KvanteTheme.Colors.cream.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadSessions()
        }
    }

    // MARK: - Page indicator

    @ViewBuilder
    private var pageIndicator: some View {
        let totalPages = viewModel.weeks.count + 1  // cover + weeks

        if totalPages <= 10 {
            // Dots
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? KvanteTheme.Colors.primary : KvanteTheme.Colors.ink.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityLabel("Side \(currentPage + 1) af \(totalPages)")
        } else {
            // Text label for many pages
            if currentPage == 0 {
                Text("Omslag")
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.4))
            } else {
                let week = viewModel.weeks[currentPage - 1]
                Text("Uge \(week.weekNumber) af \(viewModel.weeks.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.4))
            }
        }
    }

    private func pageLabel(index: Int) -> String {
        let totalPages = viewModel.weeks.count + 1
        return totalPages > 10 ? "Uge \(viewModel.weeks[index - 1].weekNumber) af \(viewModel.weeks.count)" : ""
    }
}
