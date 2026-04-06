import SwiftUI
import SwiftData

struct NewHomeView: View {
    let profile: StudentProfile
    let serverDiscovery: ServerDiscovery
    let onPractice: () -> Void

    var body: some View {
        ZStack {
            KvanteTheme.Colors.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Kvante avatar
                ZStack {
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.avatarRadius * 2)
                        .fill(KvanteTheme.Colors.kvanteAvatar)
                        .frame(width: 80, height: 80)
                    Text("🤖")
                        .font(.system(size: 44))
                }
                .padding(.bottom, 20)

                // Greeting
                Text("Hej, \(profile.name)! 👋")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)

                Text("Klar til at blive endnu skarpere til matematik i dag?")
                    .font(.subheadline)
                    .foregroundStyle(KvanteTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                Spacer()

                // Two cards side by side
                HStack(spacing: 16) {
                    // Ugematematik card
                    homeCard(
                        iconName: "book.closed",
                        iconColor: KvanteTheme.Colors.primary,
                        title: "Ugematematik",
                        subtitle: "Dine opgaver venter",
                        buttonLabel: "Start opgaver",
                        buttonStyle: KvanteTheme.TactileButtonStyle.primary,
                        action: {},
                        disabled: true
                    )

                    // Øvelser card
                    homeCard(
                        iconName: "dumbbell",
                        iconColor: KvanteTheme.Colors.teal,
                        title: "Øvelser",
                        subtitle: "Træn de emner du har sværest ved",
                        buttonLabel: "Vælg øvelse",
                        buttonStyle: KvanteTheme.TactileButtonStyle.secondary,
                        action: onPractice,
                        disabled: serverDiscovery.serverURL == nil
                    )
                }
                .padding(.horizontal, 24)

                // Server status
                if serverDiscovery.serverURL == nil {
                    Text(serverDiscovery.isSearching
                        ? "Leder efter serveren..."
                        : "Ingen server fundet")
                        .font(.caption)
                        .foregroundStyle(KvanteTheme.Colors.textMuted)
                        .padding(.top, 12)
                }

                Spacer()
            }
        }
    }

    // MARK: - Home Card

    private func homeCard(
        iconName: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        buttonLabel: String,
        buttonStyle: KvanteTheme.TactileButtonStyle,
        action: @escaping () -> Void,
        disabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon box
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.iconBoxRadius)
                .fill(iconColor.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconColor)
                )

            // Title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KvanteTheme.Colors.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(KvanteTheme.Colors.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // CTA button
            Button(action: action) {
                Text(buttonLabel)
                    .font(KvanteTheme.Fonts.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(buttonStyle)
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                .fill(KvanteTheme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KvanteTheme.Shapes.cardRadius)
                        .stroke(KvanteTheme.Colors.cardBorder, lineWidth: 2)
                )
        )
    }
}
