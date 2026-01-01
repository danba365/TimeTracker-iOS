import SwiftUI

/// Main tab view with bottom navigation
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    
    @State private var selectedTab: Tab = .tasks
    
    enum Tab {
        case tasks, chat, voice
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .tasks:
                    TasksView()
                case .chat:
                    ChatView()
                case .voice:
                    VoiceView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(taskManager)
            
            // Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "calendar",
                label: "משימות",
                isSelected: selectedTab == .tasks
            ) {
                selectedTab = .tasks
            }
            
            TabBarButton(
                icon: "message",
                label: "צ'אט",
                isSelected: selectedTab == .chat
            ) {
                selectedTab = .chat
            }
            
            TabBarButton(
                icon: "mic",
                label: "קול",
                isSelected: selectedTab == .voice
            ) {
                selectedTab = .voice
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Rectangle()
                .fill(Color(hex: "0f0f23"))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "a78bfa") : Color(hex: "64748b"))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "a78bfa") : Color(hex: "64748b"))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
}

