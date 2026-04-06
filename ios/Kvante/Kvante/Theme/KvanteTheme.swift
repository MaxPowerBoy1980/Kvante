import SwiftUI

enum KvanteTheme {
    // MARK: - Colors

    enum Colors {
        // Background
        static let backgroundStart = Color(hex: "faf6f0")
        static let backgroundEnd = Color(hex: "fff8ee")
        static var background: LinearGradient {
            LinearGradient(
                colors: [backgroundStart, backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        // Primary action / student bubbles
        static let primary = Color(hex: "e85d26")
        static let primaryShadow = Color(hex: "c44a1a")

        // Kvante bubbles
        static let kvanteBubble = Color.white
        static let kvanteBubbleBorder = Color(hex: "f0ebe3")

        // Student bubbles
        static let studentBubble = Color(hex: "e85d26")

        // Success / completion
        static let success = Color(hex: "4caf50")
        static let successSecondary = Color(hex: "2aa68a")
        static var successGradient: LinearGradient {
            LinearGradient(
                colors: [success, successSecondary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        // Øvelser button
        static let teal = Color(hex: "2aa68a")
        static let tealShadow = Color(hex: "1e8a6f")

        // Pending / muted
        static let muted = Color(hex: "f0ebe3")
        static let mutedText = Color(hex: "c4b89e")

        // Text
        static let textPrimary = Color(hex: "3d2c1e")
        static let textSecondary = Color(hex: "8b7355")

        // Tips
        static let tipBackground = Color(hex: "fff9f0")
        static let tipBorder = Color(hex: "fde4b8")
        static let tipLabel = Color(hex: "92610a")

        // Kvante avatar background
        static let kvanteAvatar = Color(hex: "e85d26")

        // Input bar
        static let inputBackground = Color(hex: "f0ebe3")
        static let sendActive = Color(hex: "e85d26")
        static let sendInactive = Color(hex: "c4b89e")

        // Wrong answer (warm, not red)
        static let wrong = Color(hex: "e85d26")

        // Assignment intro
        static let assignmentBackground = Color(hex: "e85d26")
    }

    // MARK: - Fonts

    enum Fonts {
        static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static let greeting = Font.system(size: 28, weight: .bold, design: .rounded)
        static let assignmentText = Font.system(size: 28, weight: .bold, design: .rounded)
        static let buttonLabel = Font.system(size: 15, weight: .bold, design: .rounded)
        static let body = Font.body
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.bold)
        static let subtitle = Font.subheadline
    }

    // MARK: - Shapes

    enum Shapes {
        static let bubbleRadius: CGFloat = 20
        static let cardRadius: CGFloat = 18
        static let buttonRadius: CGFloat = 16
        static let inputRadius: CGFloat = 20
        static let smallRadius: CGFloat = 14
        static let buttonShadowHeight: CGFloat = 6
    }

    // MARK: - Button Styles

    /// Tactile 3D button that looks like a pressable plastic block (Toca Boca style)
    /// - Solid darker bottom border creates depth
    /// - 2px dark brown outline makes it pop against cream background
    /// - Press animation: button moves down and shadow disappears
    struct TactileButtonStyle: ButtonStyle {
        let fillColor: Color
        let shadowColor: Color
        let outlineColor: Color

        init(fill: Color, shadow: Color, outline: Color = Colors.textPrimary) {
            self.fillColor = fill
            self.shadowColor = shadow
            self.outlineColor = outline
        }

        /// Primary orange button
        static var primary: TactileButtonStyle {
            TactileButtonStyle(fill: Colors.primary, shadow: Colors.primaryShadow)
        }

        /// Teal/green secondary button
        static var secondary: TactileButtonStyle {
            TactileButtonStyle(fill: Colors.teal, shadow: Colors.tealShadow)
        }

        func makeBody(configuration: Configuration) -> some View {
            let pressed = configuration.isPressed
            configuration.label
                .offset(y: pressed ? Shapes.buttonShadowHeight : 0)
                .background(
                    RoundedRectangle(cornerRadius: Shapes.buttonRadius)
                        .fill(shadowColor)
                        .offset(y: Shapes.buttonShadowHeight)
                        .opacity(pressed ? 0 : 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: Shapes.buttonRadius)
                        .fill(fillColor)
                        .offset(y: pressed ? Shapes.buttonShadowHeight : 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Shapes.buttonRadius)
                        .stroke(outlineColor.opacity(0.3), lineWidth: 2)
                        .offset(y: pressed ? Shapes.buttonShadowHeight : 0)
                )
                .animation(.easeInOut(duration: 0.1), value: pressed)
        }
    }

    // MARK: - Avatars

    static let studentAvatars: [(emoji: String, name: String)] = [
        ("🐱", "Kat"),
        ("🦉", "Ugle"),
        ("🐻", "Bjørn"),
        ("🐰", "Kanin"),
        ("🐸", "Frø"),
        ("🦊", "Ræv"),
        ("🔵", "Blå"),
        ("🟣", "Lilla"),
        ("🟠", "Orange"),
        ("🔶", "Diamant"),
    ]
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
