import SwiftUI

// MARK: - Area Label Component
// Small area symbol on a softly tinted rounded square
// Uses custom designer symbols from asset catalog (32pt grid, 2.2 stroke, template rendering)

struct AreaLabel: View {
    let area: SunriseTheme.LifeArea
    let size: CGFloat
    
    init(area: SunriseTheme.LifeArea, size: CGFloat = 44) {
        self.area = area
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Soft tinted background (12% opacity per tokens)
            RoundedRectangle(
                cornerRadius: SunriseTheme.CornerRadius.areaLabel,
                style: .continuous
            )
            .fill(area.color.opacity(0.12))
            
            // Custom symbol from asset catalog
            Image(area.symbolName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.55, height: size * 0.55)
                .foregroundColor(area.color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Area Label with Text

struct AreaLabelWithText: View {
    let area: SunriseTheme.LifeArea
    let showHours: Bool
    let hours: Double?
    
    init(area: SunriseTheme.LifeArea, showHours: Bool = false, hours: Double? = nil) {
        self.area = area
        self.showHours = showHours
        self.hours = hours
    }
    
    var body: some View {
        HStack(spacing: SunriseTheme.Spacing.gap) {
            AreaLabel(area: area, size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(area.rawValue)
                    .font(SunriseTheme.Typography.bodyEmphasized)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                
                if showHours, let hours = hours {
                    Text("\(Int(hours))h")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Labels - Light") {
    VStack(spacing: 16) {
        ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
            HStack {
                AreaLabel(area: area, size: 44)
                Text(area.rawValue)
                    .font(SunriseTheme.Typography.body)
                Spacer()
            }
        }
    }
    .padding()
    .background(SunriseTheme.Colors.background)
}

#Preview("Single Labels - Dark") {
    VStack(spacing: 16) {
        ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
            HStack {
                AreaLabel(area: area, size: 44)
                Text(area.rawValue)
                    .font(SunriseTheme.Typography.body)
                    .foregroundColor(SunriseTheme.Colors.textPrimary)
                Spacer()
            }
        }
    }
    .padding()
    .background(SunriseTheme.Colors.background)
    .preferredColorScheme(.dark)
}

#Preview("With Text & Hours") {
    VStack(alignment: .leading, spacing: 16) {
        AreaLabelWithText(area: .sport, showHours: true, hours: 5)
        AreaLabelWithText(area: .learning, showHours: true, hours: 8)
        AreaLabelWithText(area: .hobbies, showHours: true, hours: 3)
        AreaLabelWithText(area: .wife, showHours: true, hours: 12)
        AreaLabelWithText(area: .kidsFamily, showHours: true, hours: 15)
        AreaLabelWithText(area: .friends, showHours: true, hours: 4)
    }
    .padding()
    .background(SunriseTheme.Colors.background)
}

#Preview("Compact Grid") {
    LazyVGrid(
        columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ],
        spacing: 16
    ) {
        ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
            VStack(spacing: 8) {
                AreaLabel(area: area, size: 60)
                Text(area.rawValue)
                    .font(SunriseTheme.Typography.caption)
                    .foregroundColor(SunriseTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    .padding()
    .background(SunriseTheme.Colors.background)
}

#Preview("RTL - Hebrew") {
    VStack(alignment: .trailing, spacing: 16) {
        ForEach(SunriseTheme.LifeArea.allCases, id: \.self) { area in
            HStack(spacing: SunriseTheme.Spacing.gap) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(area.rawValue)
                        .font(SunriseTheme.Typography.hebrewTitle)
                        .foregroundColor(SunriseTheme.Colors.textPrimary)
                    Text("5 שעות")
                        .font(SunriseTheme.Typography.caption)
                        .foregroundColor(SunriseTheme.Colors.textSecondary)
                }
                AreaLabel(area: area, size: 32)
            }
        }
    }
    .padding()
    .background(SunriseTheme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
}
