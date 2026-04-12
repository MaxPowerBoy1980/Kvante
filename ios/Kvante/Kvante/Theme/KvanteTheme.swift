import SwiftUI

enum KvanteTheme {
    // MARK: - Colors

    enum Colors {
        // Background — warm paper
        static let cream = Color(hex: "FDFBF7")

        // Ink — dark brown text
        static let ink = Color(hex: "3D2C1E")
        static let inkLight = ink.opacity(0.6)
        static let inkSubtle = ink.opacity(0.05)

        // Primary — warm orange
        static let primary = Color(hex: "E85D26")
        static let primaryShadow = Color(hex: "C44D1F")

        // Teal — secondary / student bubbles
        static let teal = Color(hex: "2AA68A")
        static let tealShadow = Color(hex: "218A72")

        // Green — success
        static let success = Color(hex: "4CAF50")
        static let successShadow = Color(hex: "3D8B40")

        // Kvante bubbles — white with subtle border
        static let kvanteBubble = Color.white
        static let kvanteBubbleBorder = ink.opacity(0.05)

        // Student bubbles — teal
        static let studentBubble = Color(hex: "2AA68A")
        static let studentBubbleShadow = Color(hex: "218A72")

        // Cards — white with subtle border
        static let card = Color.white
        static let cardBorder = ink.opacity(0.05)

        // Text aliases
        static let textPrimary = ink
        static let textSecondary = ink.opacity(0.6)
        static let textMuted = ink.opacity(0.4)
        static let textPlaceholder = ink.opacity(0.2)

        // Pending / muted backgrounds
        static let muted = Color(hex: "f0ebe3")
        static let mutedText = ink.opacity(0.4)

        // Tips — teal accent
        static let tipBackground = Color.white
        static let tipBorder = teal.opacity(0.2)
        static let tipLabel = teal

        // Kvante avatar
        static let kvanteAvatar = Color(hex: "E85D26")

        // Input
        static let sendActive = Color(hex: "E85D26")
        static let sendInactive = ink.opacity(0.4)

        // Assignment intro
        static let assignmentBackground = Color(hex: "E85D26")

        // Wrong answer
        static let wrong = Color(hex: "E85D26")

        // Kvante character
        static let kvanteFace = Color(hex: "B8D8D0")  // Light teal body
        static let kvanteDotBlue = Color(hex: "2A5A8A")  // Bryst-panel dots
        static let coral = Color(hex: "E8507A")  // Lightning zigzag / celebration
        static let antennePink = Color(hex: "E8507A")  // Antenna pom-pom (same as coral)

        // Rob pixelart-derived colors
        static let robBlue = Color(hex: "5B9EB5")       // Rob's head — used for done-chips
        static let backgroundWarm = Color(hex: "FFF7ED") // Warm cream for triumph card gradient

        // Difficulty level colors
        static let difficultyEasy = teal
        static let difficultyNormal = primary
        static let difficultyHard = Color(hex: "6c5ce7")  // Purple

        // Legacy aliases for compatibility
        static let backgroundStart = cream
        static var background: LinearGradient {
            LinearGradient(colors: [cream, cream], startPoint: .top, endPoint: .bottom)
        }
        static var successGradient: LinearGradient {
            LinearGradient(colors: [success, success], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: - Fonts
    //
    // Clean geometric sans-serif (SF Pro default) — not rounded.
    // Wide apertures, professional but friendly. Like Inter/Montserrat.

    enum Fonts {
        static func clean(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        static let greeting = Font.system(size: 28, weight: .bold)
        static let assignmentText = Font.system(size: 26, weight: .bold)
        static let buttonLabel = Font.system(size: 16, weight: .semibold)
        static let body = Font.body
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.semibold)
        static let subtitle = Font.subheadline
    }

    // MARK: - Shapes
    //
    // Consistent, subtle rounding — clean/sturdy, not bubbly.
    // 16px standard. Nothing above 20px.

    enum Shapes {
        static let bubbleRadius: CGFloat = 16
        static let cardRadius: CGFloat = 24
        static let buttonRadius: CGFloat = 12
        static let iconBoxRadius: CGFloat = 16
        static let avatarRadius: CGFloat = 12
        static let inputRadius: CGFloat = 16
        static let smallRadius: CGFloat = 12
        static let buttonShadowHeight: CGFloat = 4
    }

    // MARK: - Celebration Timing

    enum Celebration {
        static let chatFlashDuration: Double = 0.3
        static let headerDelay: Double = 0.6
        static let dotPulseDuration: Double = 0.4
        static let setCompleteZigzagDuration: Double = 0.8
    }

    // MARK: - Button Styles
    //
    // Flat-top depth: crisp darker bottom edge (5px).
    // Feels like a firm, satisfying press — not a squishy toy.

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
