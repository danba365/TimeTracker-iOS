import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum SorbetTheme {

    enum ViewTint {
        case today
        case tasks
        case coach
        case people
        case settings

        var background: Color {
            switch self {
            case .today:    return Color(hex: "FFE3D4")
            case .tasks:    return Color(hex: "D6F0E2")
            case .coach:    return Color(hex: "DBE8FF")
            case .people:   return Color(hex: "ECDFFF")
            case .settings: return Color(hex: "FBEECF")
            }
        }

        var accent: Color {
            switch self {
            case .today:    return Color(hex: "FF8A6B")
            case .tasks:    return Color(hex: "3BBF85")
            case .coach:    return Color(hex: "5B8DEF")
            case .people:   return Color(hex: "9758E8")
            case .settings: return Color(hex: "EAB93C")
            }
        }
    }

    enum Palette {
        static let neutralPage  = Color(hex: "FBF4EE")
        static let surface      = Color.white
        static let border       = Color(hex: "F1E6DC")
        static let textPrimary  = Color(hex: "2E2A3A")
        static let textSecondary = Color(hex: "6B5F57")
        static let textTertiary = Color(hex: "9A8C82")

        static let priorityHigh   = Color(hex: "FF7A6B")
        static let priorityMedium = Color(hex: "FFB04D")
        static let priorityLow    = Color(hex: "5B8DEF")
        static let statusDone     = Color(hex: "3BBF85")
    }

    enum Radius {
        static let card: CGFloat = 22
        static let lg: CGFloat = 18
        static let md: CGFloat = 14
        static let sm: CGFloat = 10
    }

    enum Shadow {
        static let card = (color: Color(red: 120/255, green: 80/255, blue: 60/255, opacity: 0.07),
                           radius: CGFloat(12),
                           x: CGFloat(0),
                           y: CGFloat(4))
        static let lifted = (color: Color(red: 120/255, green: 80/255, blue: 60/255, opacity: 0.10),
                             radius: CGFloat(24),
                             x: CGFloat(0),
                             y: CGFloat(10))
    }
}

extension View {
    func sorbetCard(radius: CGFloat = SorbetTheme.Radius.card) -> some View {
        self
            .background(SorbetTheme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: SorbetTheme.Shadow.card.color,
                radius: SorbetTheme.Shadow.card.radius,
                x: SorbetTheme.Shadow.card.x,
                y: SorbetTheme.Shadow.card.y
            )
    }
}
