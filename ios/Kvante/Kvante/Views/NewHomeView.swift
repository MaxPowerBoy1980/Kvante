import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void

    var body: some View {
        ZStack {
            KvanteTheme.Colors.background.ignoresSafeArea()

            // Subtle decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(KvanteTheme.Colors.tipBorder.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width - 60, y: -30)
                Circle()
                    .fill(KvanteTheme.Colors.success.opacity(0.15))
                    .frame(width: 90, height: 90)
                    .offset(x: -30, y: geo.size.height - 200)
            }

            VStack(spacing: 0) {
                // Header with avatar + greeting
                HStack(spacing: 14) {
                    Text(profile.avatarName)
                        .font(.system(size: 44))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hej \(profile.name)!")
                            .font(KvanteTheme.Fonts.greeting)
                            .foregroundStyle(KvanteTheme.Colors.textPrimary)
                        if serverDiscovery.serverURL == nil {
                            Text(serverDiscovery.isSearching
                                ? "Leder efter serveren..."
                                : "Ingen server fundet")
                                .font(.caption)
                                .foregroundStyle(KvanteTheme.Colors.mutedText)
                        } else {
                            Text("Klar til matematik?")
                                .font(.subheadline)
                                .foregroundStyle(KvanteTheme.Colors.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Spacer()

                // Card-style action buttons
                HStack(spacing: 16) {
                    // Ugematematik — primary
                    Button(action: {}) {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 40, weight: .medium))
                            Text("Ugematematik")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                    }
                    .buttonStyle(KvanteTheme.TactileButtonStyle.primary)
                    .disabled(true)
                    .opacity(0.5)

                    // Øvelser — secondary
                    Button(action: onPractice) {
                        VStack(spacing: 12) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 40, weight: .medium))
                            Text("Øvelser")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                    }
                    .buttonStyle(KvanteTheme.TactileButtonStyle.secondary)
                    .disabled(serverDiscovery.serverURL == nil)
                    .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
