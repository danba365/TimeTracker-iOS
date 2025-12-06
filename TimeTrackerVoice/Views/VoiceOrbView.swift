import SwiftUI

/// Animated voice orb that provides visual feedback during conversation
struct VoiceOrbView: View {
    let state: VoiceState
    let audioLevel: Float
    let onTap: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    private let orbSize: CGFloat = 160
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            gradientColors.first!.opacity(0.3),
                            .clear
                        ]),
                        center: .center,
                        startRadius: orbSize / 2,
                        endRadius: orbSize
                    )
                )
                .frame(width: orbSize * 2, height: orbSize * 2)
                .opacity(state.isActive ? 1 : 0.3)
            
            // Pulse rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(gradientColors.first!, lineWidth: 2)
                    .frame(width: orbSize, height: orbSize)
                    .scaleEffect(pulseScale + CGFloat(index) * 0.2)
                    .opacity(state == .listening ? Double(3 - index) / 6 : 0)
            }
            
            // Main orb
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(orbScale)
                .rotationEffect(.degrees(rotation))
                .shadow(color: gradientColors.first!.opacity(0.5), radius: 20, x: 0, y: 10)
                .overlay(
                    // Highlight
                    Ellipse()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.white.opacity(0.4), .clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: orbSize * 0.35, height: orbSize * 0.2)
                        .offset(x: -20, y: -50)
                        .rotationEffect(.degrees(-25))
                )
                .overlay(
                    // Audio level indicator
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: orbSize - 20, height: orbSize - 20)
                        .scaleEffect(1 + CGFloat(audioLevel) * 0.2)
                        .opacity(state == .listening ? 1 : 0)
                )
            
            // Center icon
            Image(systemName: stateIcon)
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .contentShape(Circle())
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap()
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: state) { _ in
            updateAnimations()
        }
    }
    
    // MARK: - Computed Properties
    
    private var gradientColors: [Color] {
        switch state {
        case .idle:
            return [Color(hex: "6366f1"), Color(hex: "8b5cf6"), Color(hex: "a78bfa")]
        case .listening:
            return [Color(hex: "7c3aed"), Color(hex: "a855f7"), Color(hex: "c084fc")]
        case .processing:
            return [Color(hex: "3b82f6"), Color(hex: "60a5fa"), Color(hex: "93c5fd")]
        case .speaking:
            return [Color(hex: "10b981"), Color(hex: "34d399"), Color(hex: "6ee7b7")]
        case .error:
            return [Color(hex: "ef4444"), Color(hex: "f87171"), Color(hex: "fca5a5")]
        }
    }
    
    private var orbScale: CGFloat {
        switch state {
        case .idle:
            return isAnimating ? 1.05 : 1.0
        case .listening:
            return 1.0 + CGFloat(audioLevel) * 0.15
        case .processing:
            return 0.95
        case .speaking:
            return isAnimating ? 1.1 : 1.0
        case .error:
            return 1.0
        }
    }
    
    private var stateIcon: String {
        switch state {
        case .idle:
            return "mic.fill"
        case .listening:
            return "waveform"
        case .processing:
            return "ellipsis"
        case .speaking:
            return "speaker.wave.2.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        updateAnimations()
    }
    
    private func updateAnimations() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
        
        switch state {
        case .listening:
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 2.0
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        case .processing:
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            pulseScale = 1.0
        case .speaking:
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
            pulseScale = 1.0
        default:
            pulseScale = 1.0
            rotation = 0
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

#Preview {
    ZStack {
        Color(hex: "1a1a2e").ignoresSafeArea()
        VoiceOrbView(state: .listening, audioLevel: 0.5) {}
    }
}

