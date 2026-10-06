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

/// Floating tab bar (iOS 26 style): Tasks, Chat and Contacts in a glass
/// capsule, with Voice as a separate round mic button.
struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                TabBarButton(icon: "calendar", label: L10n.tabTasks, isSelected: selectedTab == .tasks) {
                    selectedTab = .tasks
                }
                TabBarButton(icon: "bubble.left", label: L10n.tabChat, isSelected: selectedTab == .chat) {
                    selectedTab = .chat
                }
                TabBarButton(icon: "person.2", label: L10n.tabContacts, isSelected: selectedTab == .contacts) {
                    selectedTab = .contacts
                }
            }
            .padding(4)
            .frame(height: 62)
            .glassBackground(in: Capsule())

            Button {
                selectedTab = .voice
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(NativePalette.accent)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(selectedTab == .voice ? NativePalette.accentSoft : .clear))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassBackground(in: Circle())
            .accessibilityLabel(L10n.tabVoice)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
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
            VStack(spacing: 3) {
                Image(systemName: isSelected && icon != "calendar" ? "\(icon).fill" : icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 24)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? NativePalette.accent : NativePalette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Capsule().fill(isSelected ? NativePalette.segment : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass

extension View {
    /// Liquid Glass on iOS 26, a translucent material on earlier versions.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            materialBackground(in: shape)
        }
        #else
        materialBackground(in: shape)
        #endif
    }

    private func materialBackground<S: Shape>(in shape: S) -> some View {
        self
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
        .environmentObject(PeopleManager.shared)
        .environmentObject(EventManager.shared)
}

