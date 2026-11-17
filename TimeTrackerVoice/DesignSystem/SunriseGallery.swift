import SwiftUI

// MARK: - Sunrise Design System Gallery
// Debug-only preview showing all tokens and components
// Supports light/dark mode toggle and RTL preview

struct SunriseGallery: View {
    @State private var colorScheme: ColorScheme = .light
    @State private var isRTL: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SunriseTheme.Spacing.sectionSpacing) {
                    // Controls
                    controlsSection
                    
                    // Colors
                    colorsSection
                    
                    // Typography
                    typographySection
                    
                    // Spacing & Radii
                    spacingSection
                    
                    // Life Areas
                    lifeAreasSection
                    
                    // Components
                    componentsSection
                }
                .padding(SunriseTheme.Spacing.screen)
            }
            .background(SunriseTheme.Colors.background)
            .navigationTitle("Sunrise Design System")
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        }
        .preferredColorScheme(colorScheme)
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: SunriseTheme.Spacing.card) {
            sectionHeader("Preview Controls")
            
            HStack(spacing: SunriseTheme.Spacing.gap) {
                Button(action: { colorScheme = colorScheme == .light ? .dark : .light }) {
                    Label(
                        colorScheme == .light ? "Switch to Dark" : "Switch to Light",
                        systemImage: colorScheme == .light ? "moon.fill" : "sun.max.fill"
                    )
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(SunriseTheme.Spacing.md)
                }
                .sunriseCard()
                
                Button(action: { isRTL.toggle() }) {
                    Label(
                        isRTL ? "LTR" : "RTL",
                        systemImage: isRTL ? "arrow.left" : "arrow.right"
                    )
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(SunriseTheme.Spacing.md)
                }
                .sunriseCard()
            }
        }
    }
    
    // MARK: - Colors
    
    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: SunriseTheme.Spacing.card) {
            sectionHeader("Colors")
            
            VStack(spacing: SunriseTheme.Spacing.gap) {
                colorRow("Brand Coral", color: SunriseTheme.Colors.accent, note: "#E8613C → #E07A55 (dark)")
                colorRow("Background Warm Paper", color: SunriseTheme.Colors.background, note: "#FBF7F3 → #0E0F11 (dark)")
                colorRow("Surface", color: SunriseTheme.Colors.surface, note: "#FFFFFF → #17181B (dark)")
                colorRow("Text Primary", color: SunriseTheme.Colors.textPrimary, note: "#2B2320 → #F2F0ED (dark)")
                colorRow("Text Secondary", color: SunriseTheme.Colors.textSecondary, note: "#8C7F76 → #7D7A76 (dark)")
            }
            .sunriseCard()
        }
    }
    
    // MARK: - Typography
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: SunriseTheme.Spacing.card) {
            sectionHeader("Typography")
            
            VStack(alignment: .leading, spacing: SunriseTheme.Spacing.card) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("48")
                        .font(SunriseTheme.Typography.hourNumber(size: 48))
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("Hour Number - Rubik Medium (custom size)")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large Title")
                        .font(SunriseTheme.Typography.largeTitle)
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("Large Title - Rubik 28pt, weight 600")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title Text")
                        .font(SunriseTheme.Typography.title)
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("Title - Rubik 22pt, weight 600")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body text for longer reading passages. System font for comfortable reading.")
                        .font(SunriseTheme.Typography.body)
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("Body - SF Pro System")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("כותרת בעברית")
                        .font(SunriseTheme.Typography.hebrewTitle)
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("Hebrew Title - Rubik 22pt (RTL-safe)")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
            }
            .padding(SunriseTheme.Spacing.card)
            .sunriseCard()
        }
    }
    
    // MARK: - Spacing
    
    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
            sectionHeader("Spacing & Corner Radii")
            
            VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
                Text("Spacing Scale")
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: 8) {
                    spacingRow("XXS", value: SunriseTheme.Spacing.xxs)
                    spacingRow("XS", value: SunriseTheme.Spacing.xs)
                    spacingRow("SM", value: SunriseTheme.Spacing.sm)
                    spacingRow("MD", value: SunriseTheme.Spacing.md)
                    spacingRow("LG", value: SunriseTheme.Spacing.lg)
                    spacingRow("XL", value: SunriseTheme.Spacing.xl)
                    spacingRow("XXL", value: SunriseTheme.Spacing.xxl)
                }
                
                Divider()
                    .padding(.vertical, SunriseTheme.Spacing.xs)
                
                Text("Corner Radii")
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                
                HStack(spacing: SunriseTheme.Spacing.md) {
                    radiusExample("XS", radius: SunriseTheme.CornerRadius.xs)
                    radiusExample("SM", radius: SunriseTheme.CornerRadius.sm)
                    radiusExample("MD", radius: SunriseTheme.CornerRadius.md)
                    radiusExample("LG", radius: SunriseTheme.CornerRadius.lg)
                }
            }
            .padding(SunriseTheme.Spacing.card)
            .sunriseCard()
        }
    }
    
    // MARK: - Life Areas
    
    private var lifeAreasSection: some View {
        VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
            sectionHeader("Life Areas")
            
            Text("Final colors from designer's handoff")
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
                .padding(.horizontal, SunriseTheme.Spacing.card)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: SunriseTheme.Spacing.md
            ) {
                ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
                    VStack(spacing: SunriseTheme.Spacing.xs) {
                        Circle()
                            .fill(area.color)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(area.symbolName)
                            .renderingMode(.template)
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                        
                        Text(area.rawValue)
                            .font(SunriseTheme.Typography.caption)
                            .foregroundColor(SunriseTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(SunriseTheme.Spacing.sm)
                }
            }
            .padding(SunriseTheme.Spacing.card)
            .sunriseCard()
        }
    }
    
    // MARK: - Components
    
    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
            sectionHeader("Components")
            
            // Balance Stones
            VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
                Text("Balance Stone States")
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                
                Text("6 ellipses, r=5+15√(hours/max), fixed slots")
                    .font(SunriseTheme.Typography.caption)
                    .foregroundColor(SunriseTheme.Colors.textSecondary)
                
                HStack(spacing: SunriseTheme.Spacing.lg) {
                    VStack {
                        BalanceStone.balanced(size: 80)
                        Text("Balanced")
                            .font(SunriseTheme.Typography.caption)
                            .foregroundColor(SunriseTheme.Colors.textSecondary)
                    }
                    
                    VStack {
                        BalanceStone.offBalance(size: 80)
                        Text("Off Balance")
                            .font(SunriseTheme.Typography.caption)
                            .foregroundColor(SunriseTheme.Colors.textSecondary)
                    }
                    
                    VStack {
                        BalanceStone.empty(size: 80)
                        Text("Empty")
                            .font(SunriseTheme.Typography.caption)
                            .foregroundColor(SunriseTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(SunriseTheme.Spacing.card)
            .sunriseCard()
            
            // Area Labels
            VStack(alignment: .leading, spacing: SunriseTheme.Spacing.md) {
                Text("Area Labels")
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                
                Text("Custom symbols: 32pt grid, 2.2 stroke, 12% tint")
                    .font(SunriseTheme.Typography.caption)
                    .foregroundColor(SunriseTheme.Colors.textSecondary)
                
                VStack(alignment: .leading, spacing: SunriseTheme.Spacing.sm) {
                    ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
                        AreaLabelWithText(
                            area: area,
                            showHours: true,
                            hours: Double.random(in: 2...12)
                        )
                    }
                }
            }
            .padding(SunriseTheme.Spacing.card)
            .sunriseCard()
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SunriseTheme.Typography.title())
            .foregroundColor(SunriseTheme.Colors.textPrimary)
    }
    
    private func colorRow(_ name: String, color: Color, note: String) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                Text(note)
                    .font(SunriseTheme.Typography.caption)
                    .foregroundColor(SunriseTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(SunriseTheme.Spacing.sm)
    }
    
    private func spacingRow(_ name: String, value: CGFloat) -> some View {
        HStack(spacing: SunriseTheme.Spacing.md) {
            Rectangle()
                .fill(SunriseTheme.Colors.accent)
                .frame(width: value, height: 20)
            
            Text("\(name): \(Int(value))pt")
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    private func radiusExample(_ name: String, radius: CGFloat) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(SunriseTheme.Colors.accent.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(SunriseTheme.Colors.accent, lineWidth: 2)
                )
            
            Text(name)
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
            
            Text("\(Int(radius))pt")
                .font(SunriseTheme.Typography.caption2)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SunriseGallery()
}

#Preview("Dark Mode") {
    SunriseGallery()
        .preferredColorScheme(.dark)
}
