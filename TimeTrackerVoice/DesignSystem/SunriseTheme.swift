import SwiftUI

// MARK: - Sunrise with the Stones Design System
// Foundation layer for the personal life-balance planner
// Supports light/dark modes and full RTL (Hebrew/English)

enum SunriseTheme {
    
    // MARK: - Life Areas
    
    enum LifeArea: String, CaseIterable {
        case sport = "Sport"
        case learning = "Learning"
        case hobbies = "Hobbies"
        case wife = "Wife"
        case kidsFamily = "Kids & family"
        case friends = "Friends"
        
        var color: Color {
            switch self {
            case .sport:
                return Color("AreaSport", bundle: nil)
            case .learning:
                return Color("AreaLearning", bundle: nil)
            case .hobbies:
                return Color("AreaHobbies", bundle: nil)
            case .wife:
                return Color("AreaWife", bundle: nil)
            case .kidsFamily:
                return Color("AreaKidsFamily", bundle: nil)
            case .friends:
                return Color("AreaFriends", bundle: nil)
            }
        }
        
        // TODO-from-Figma: Replace with final SF Symbol template files from designer
        var symbolName: String {
            switch self {
            case .sport: return "sport"
            case .learning: return "learning"
            case .hobbies: return "hobbies"
            case .wife: return "wife"
            case .kidsFamily: return "kids_family"
            case .friends: return "friends"
            }
        }
    }
    
    // MARK: - Semantic Colors
    
    enum Colors {
        // Core brand
        static let accent = Color("BrandCoral", bundle: nil)
        
        // Backgrounds
        static let background = Color("BackgroundWarmPaper", bundle: nil)
        static let surface = Color("Surface", bundle: nil)
        
        // Text
        static let textPrimary = Color("TextPrimary", bundle: nil)
        static let textSecondary = Color("TextSecondary", bundle: nil)
        
        // System (using dynamic system colors for consistency)
        static let systemBackground = Color(uiColor: .systemBackground)
        static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    }
    
    // MARK: - Typography
    // From designer's tokens: Rubik for titles/headlines/Hebrew, SF Pro for body
    
    enum Typography {
        // Large title - Rubik 28pt, weight 600
        static let largeTitle = Font.custom("Rubik-Medium", size: 28, relativeTo: .largeTitle)
        
        // Title - Rubik 22pt, weight 600
        static let title = Font.custom("Rubik-Medium", size: 22, relativeTo: .title)
        
        // Body - System (SF Pro) 16pt, weight 400
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyEmphasized = Font.system(size: 16, weight: .medium)
        
        // Caption - System (SF Pro) 13pt, weight 400
        static let caption = Font.system(size: 13, weight: .regular)
        
        // For Hebrew text - Rubik supports Hebrew beautifully
        static let hebrewTitle = Font.custom("Rubik-Medium", size: 22, relativeTo: .title)
        static let hebrewBody = Font.custom("Rubik-Regular", size: 16, relativeTo: .body)
        
        // Large hour numbers - Rubik Medium, custom size
        static func hourNumber(size: CGFloat = 72) -> Font {
            Font.custom("Rubik-Medium", size: size, relativeTo: .largeTitle)
        }
    }
    
    // MARK: - Spacing Scale
    // From designer's tokens
    
    enum Spacing {
        static let screen: CGFloat = 22  // screen padding
        static let card: CGFloat = 14    // card padding
        static let gap: CGFloat = 10     // general gap between elements
        
        // Additional semantic spacing for flexibility
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let xl: CGFloat = 32
    }
    
    // MARK: - Corner Radii
    // From designer's tokens
    
    enum CornerRadius {
        static let card: CGFloat = 20
        static let button: CGFloat = 16
        static let tile: CGFloat = 12
        static let chip: CGFloat = 999  // fully rounded
        
        // Alias for area labels
        static let areaLabel: CGFloat = tile
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static let soft = (
            color: Color.black.opacity(0.08),
            radius: CGFloat(12),
            x: CGFloat(0),
            y: CGFloat(4)
        )
        
        static let lifted = (
            color: Color.black.opacity(0.12),
            radius: CGFloat(20),
            x: CGFloat(0),
            y: CGFloat(8)
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the standard Sunrise card style
    func sunriseCard(radius: CGFloat = SunriseTheme.CornerRadius.card) -> some View {
        self
            .background(SunriseTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: SunriseTheme.Shadows.soft.color,
                radius: SunriseTheme.Shadows.soft.radius,
                x: SunriseTheme.Shadows.soft.x,
                y: SunriseTheme.Shadows.soft.y
            )
    }
    
    /// Apply the lifted card style (for interactive elements)
    func sunriseLiftedCard(radius: CGFloat = SunriseTheme.CornerRadius.card) -> some View {
        self
            .background(SunriseTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: SunriseTheme.Shadows.lifted.color,
                radius: SunriseTheme.Shadows.lifted.radius,
                x: SunriseTheme.Shadows.lifted.x,
                y: SunriseTheme.Shadows.lifted.y
            )
    }
}
