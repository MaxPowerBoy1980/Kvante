import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hej, \(profile.name)!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(profile.gradeLevel). klasse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Connection indicator
                    Image(systemName: serverDiscovery.serverURL != nil
                        ? "wifi.circle.fill" : "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(serverDiscovery.serverURL != nil ? .green : .red)

                    // Avatar
                    Image(systemName: profile.avatarName)
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Mode cards
            VStack(spacing: 16) {
                // Practice — active
                Button(action: onPractice) {
                    ModeCard(
                        icon: "dumbbell.fill",
                        title: "Øvelse",
                        subtitle: "Øv dig i dit eget tempo",
                        color: .orange,
                        enabled: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(serverDiscovery.serverURL == nil)
                .opacity(serverDiscovery.serverURL == nil ? 0.5 : 1)

                // Classroom — coming soon
                ModeCard(
                    icon: "person.3.fill",
                    title: "Klasseopgaver",
                    subtitle: "Kommer snart",
                    color: .blue,
                    enabled: false
                )

                // Homework — coming soon
                ModeCard(
                    icon: "book.closed.fill",
                    title: "Lektier",
                    subtitle: "Kommer snart",
                    color: .purple,
                    enabled: false
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            if serverDiscovery.serverURL == nil {
                Text(serverDiscovery.isSearching
                    ? "Leder efter Kvante-serveren..."
                    : "Ingen server fundet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let enabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(enabled ? 0.15 : 0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(enabled ? color : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(enabled ? .primary : .secondary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if enabled {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Snart")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
        .opacity(enabled ? 1 : 0.6)
    }
}
