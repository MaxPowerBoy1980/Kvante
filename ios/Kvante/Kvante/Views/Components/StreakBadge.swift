import SwiftUI

/// Displays streak flame + day count. Shows nothing if streak is 0.
struct StreakBadge: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 2) {
                Text("🔥")
                    .font(.system(size: 13))
                Text("\(streak)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KvanteTheme.Colors.ink)
            }
        }
    }
}
