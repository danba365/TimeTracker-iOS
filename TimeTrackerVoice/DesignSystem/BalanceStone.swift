import SwiftUI

// MARK: - Balance Stone Cluster
// Following designer's exact specification from tokens.json:
// - 6 ellipses (one per area) in a 100x100 box
// - radius r = 5 + 15 * sqrt(hours / maxHours)
// - rx = r * 1.15, ry = r * 0.82 (ellipse axes)
// - alternate rotation +-8deg
// - largest stone at bottom slot
// - Fixed positions from tokens.json

struct BalanceStone: View {
    enum State {
        case balanced([CGFloat])    // All areas filled, array of 6 hour values
        case offBalance([CGFloat])  // Uneven hours, array of 6 hour values
        case empty                  // No hours logged
    }
    
    let state: State
    let size: CGFloat
    
    // Fixed slot positions from tokens.json (in 100x100 coordinate space)
    private let slots: [(x: CGFloat, y: CGFloat)] = [
        (50, 66),  // slot 0
        (29, 63),  // slot 1
        (71, 62),  // slot 2
        (39, 44),  // slot 3
        (62, 43),  // slot 4
        (50, 26)   // slot 5 - top
    ]
    
    init(state: State = .balanced([5, 8, 3, 12, 10, 4]), size: CGFloat = 120) {
        self.state = state
        self.size = size
    }
    
    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 100.0  // Scale from 100x100 design space to actual size
            
            switch state {
            case .balanced(let hours):
                drawStoneCluster(context: context, hours: hours, scale: scale, maxHours: hours.max() ?? 1)
            case .offBalance(let hours):
                drawStoneCluster(context: context, hours: hours, scale: scale, maxHours: hours.max() ?? 1)
            case .empty:
                drawEmptyStones(context: context, scale: scale)
            }
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Stone Cluster Rendering
    
    private func drawStoneCluster(context: GraphicsContext, hours: [CGFloat], scale: CGFloat, maxHours: CGFloat) {
        // Sort stones by size to draw largest first (at bottom)
        let areas = SunriseTheme.LifeArea.allCases
        var stones: [(area: SunriseTheme.LifeArea, hours: CGFloat, slot: Int)] = []
        for (index, area) in areas.enumerated() {
            let hoursValue = index < hours.count ? hours[index] : 0
            stones.append((area: area, hours: hoursValue, slot: index))
        }
        
        // Sort by hours descending (largest first)
        stones.sort { $0.hours > $1.hours }
        
        // Draw each stone
        for stone in stones {
            let slotIndex = stone.slot
            let slotPos = slots[slotIndex]
            
            // Calculate radius using designer's formula
            let normalizedHours = stone.hours / maxHours
            let r = 5.0 + 15.0 * sqrt(normalizedHours)
            let rx = r * 1.15
            let ry = r * 0.82
            
            // Alternate rotation +-8deg based on slot
            let rotation: CGFloat = (slotIndex % 2 == 0) ? 8 : -8
            
            // Scale position and size
            let x = slotPos.x * scale
            let y = slotPos.y * scale
            let scaledRx = rx * scale
            let scaledRy = ry * scale
            
            // Draw the stone ellipse
            drawStone(
                context: context,
                center: CGPoint(x: x, y: y),
                rx: scaledRx,
                ry: scaledRy,
                rotation: rotation,
                color: Color(stone.area.color)
            )
        }
    }
    
    private func drawStone(context: GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat, color: Color) {
        var ctx = context
        
        // Apply rotation around center
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .degrees(rotation))
        ctx.translateBy(x: -center.x, y: -center.y)
        
        // Draw ellipse
        let rect = CGRect(
            x: center.x - rx,
            y: center.y - ry,
            width: rx * 2,
            height: ry * 2
        )
        
        let path = Path(ellipseIn: rect)
        
        // Fill with color at 85% opacity
        ctx.fill(path, with: .color(color.opacity(0.85)))
        
        // Stroke with subtle outline (1.5pt)
        ctx.stroke(path, with: .color(color.opacity(0.4)), lineWidth: 1.5)
    }
    
    // MARK: - Empty State
    
    private func drawEmptyStones(context: GraphicsContext, scale: CGFloat) {
        let grayColor = SunriseTheme.Colors.textSecondary
        
        // Just two small stones for empty state
        drawStone(
            context: context,
            center: CGPoint(x: 50 * scale, y: 60 * scale),
            rx: 8 * scale,
            ry: 6.5 * scale,
            rotation: 0,
            color: grayColor.opacity(0.2)
        )
        
        drawStone(
            context: context,
            center: CGPoint(x: 50 * scale, y: 40 * scale),
            rx: 6 * scale,
            ry: 5 * scale,
            rotation: 0,
            color: grayColor.opacity(0.15)
        )
    }
}

// MARK: - Convenience Initializers

extension BalanceStone {
    /// Create a balanced stone cluster with sample data
    static func balanced(size: CGFloat = 120) -> BalanceStone {
        BalanceStone(state: .balanced([5, 8, 3, 12, 10, 4]), size: size)
    }
    
    /// Create an off-balance stone cluster with uneven hours
    static func offBalance(size: CGFloat = 120) -> BalanceStone {
        BalanceStone(state: .offBalance([2, 12, 1, 8, 3, 1]), size: size)
    }
    
    /// Create an empty stone cluster
    static func empty(size: CGFloat = 120) -> BalanceStone {
        BalanceStone(state: .empty, size: size)
    }
}

// MARK: - Previews

#Preview("Balanced") {
    BalanceStone.balanced(size: 160)
        .padding()
        .background(SunriseTheme.Colors.background)
}

#Preview("Off Balance") {
    BalanceStone.offBalance(size: 160)
        .padding()
        .background(SunriseTheme.Colors.background)
}

#Preview("Empty Week") {
    BalanceStone.empty(size: 160)
        .padding()
        .background(SunriseTheme.Colors.background)
}

#Preview("All States") {
    HStack(spacing: 32) {
        VStack {
            BalanceStone.balanced(size: 120)
            Text("Balanced")
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
        }
        
        VStack {
            BalanceStone.offBalance(size: 120)
            Text("Off Balance")
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
        }
        
        VStack {
            BalanceStone.empty(size: 120)
            Text("Empty")
                .font(SunriseTheme.Typography.caption)
                .foregroundColor(SunriseTheme.Colors.textSecondary)
        }
    }
    .padding(32)
    .background(SunriseTheme.Colors.background)
}

#Preview("Different Hour Patterns") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            VStack {
                BalanceStone(state: .balanced([8, 8, 8, 8, 8, 8]), size: 100)
                Text("All Equal")
                    .font(SunriseTheme.Typography.caption)
            }
            VStack {
                BalanceStone(state: .balanced([15, 2, 2, 2, 2, 2]), size: 100)
                Text("One Dominant")
                    .font(SunriseTheme.Typography.caption)
            }
        }
        
        HStack(spacing: 16) {
            VStack {
                BalanceStone(state: .balanced([12, 10, 8, 6, 4, 2]), size: 100)
                Text("Gradual Decrease")
                    .font(SunriseTheme.Typography.caption)
            }
            VStack {
                BalanceStone(state: .balanced([1, 1, 1, 10, 10, 10]), size: 100)
                Text("Split Focus")
                    .font(SunriseTheme.Typography.caption)
            }
        }
    }
    .padding()
    .background(SunriseTheme.Colors.background)
}
