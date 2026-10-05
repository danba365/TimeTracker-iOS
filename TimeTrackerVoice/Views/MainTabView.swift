import SwiftUI

/// Main tab view with bottom navigation
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    @EnvironmentObject var eventManager: EventManager
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var vacationManager = VacationManager.shared

    @State private var selectedTab: Tab = .tasks
    
    enum Tab {
        case tasks, chat, voice, contacts, lists
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
                case .lists:
                    ListsView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(taskManager)
            .environmentObject(peopleManager)
            .environmentObject(eventManager)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let vacation = vacationManager.vacation() {
                    VacationTodayBanner(vacation: vacation)
                }
            }

            // Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            // Fetch events + vacations on app launch
            Task {
                await eventManager.fetchEvents()
                await vacationManager.fetchVacations()
            }
        }
    }
}

// MARK: - Vacation Banner

/// Shown at the top of the app when today falls inside a vacation.
struct VacationTodayBanner: View {
    let vacation: VacationItem
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 10) {
            Text("🏖️")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.currentLanguage == .hebrew ? "אתה בחופשה היום" : "You're on vacation today")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if let label = vacation.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.65, blue: 0.91),
                    Color(red: 0.01, green: 0.52, blue: 0.78),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
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
            
            TabBarButton(
                icon: "tray.full",
                label: L10n.tabLists,
                isSelected: selectedTab == .lists
            ) {
                selectedTab = .lists
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            Rectangle()
                .fill(SorbetTheme.Palette.surface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(SorbetTheme.Palette.border)
                        .frame(height: 1)
                }
                .shadow(color: SorbetTheme.Shadow.lifted.color, radius: 16, y: -4)
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
                    .foregroundColor(isSelected ? SorbetTheme.ViewTint.people.accent : SorbetTheme.Palette.textTertiary)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? SorbetTheme.ViewTint.people.accent : SorbetTheme.Palette.textTertiary)
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

