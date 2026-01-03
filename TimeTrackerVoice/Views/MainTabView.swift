import SwiftUI

/// Main tab view with bottom navigation
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    @EnvironmentObject var eventManager: EventManager
    @ObservedObject private var l10n = L10n.shared
    
    @State private var selectedTab: Tab = .tasks
    
    enum Tab {
        case tasks, chat, voice, contacts
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
                case .contacts:
                    ContactsView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(taskManager)
            .environmentObject(peopleManager)
            .environmentObject(eventManager)
            
            // Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            // Fetch events on app launch
            Task {
                await eventManager.fetchEvents()
            }
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "calendar",
                label: L10n.tabTasks,
                isSelected: selectedTab == .tasks
            ) {
                selectedTab = .tasks
            }
            
            TabBarButton(
                icon: "message",
                label: L10n.tabChat,
                isSelected: selectedTab == .chat
            ) {
                selectedTab = .chat
            }
            
            TabBarButton(
                icon: "mic",
                label: L10n.tabVoice,
                isSelected: selectedTab == .voice
            ) {
                selectedTab = .voice
            }
            
            TabBarButton(
                icon: "person.2",
                label: L10n.tabContacts,
                isSelected: selectedTab == .contacts
            ) {
                selectedTab = .contacts
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
    
    // Some SF Symbols don't have .fill variants
    private var iconName: String {
        if isSelected {
            // Calendar doesn't have .fill, use circle variant
            if icon == "calendar" {
                return "calendar.circle.fill"
            }
            return "\(icon).fill"
        }
        return icon
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
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
        .environmentObject(PeopleManager.shared)
        .environmentObject(EventManager.shared)
}

