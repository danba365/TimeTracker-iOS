import SwiftUI

/// Main voice interface view
struct VoiceView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    @StateObject private var realtimeClient = RealtimeAPIClient.shared
    @StateObject private var audioManager = AudioStreamManager.shared
    @ObservedObject private var l10n = L10n.shared
    
    @State private var isConversationActive = false
    @State private var showingSettings = false
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f0f23")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // Voice Orb
                VoiceOrbView(
                    state: realtimeClient.voiceState,
                    audioLevel: audioManager.audioLevel,
                    onTap: toggleConversation
                )
                
                // Status text
                Text(statusText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                // Connection indicator
                if realtimeClient.isConnected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isConversationActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isConversationActive ? "Conversation active" : "Ready")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 12)
                }
                
                // Last response
                if !realtimeClient.lastResponse.isEmpty {
                    Text(realtimeClient.lastResponse)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94a3b8"))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                }
                
                Spacer()
                
                // Tips
                tipsView
            }
        }
        .onAppear {
            checkAPIKey()
            loadData()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
                .environmentObject(peopleManager)
        }
        .alert(L10n.enterAPIKey, isPresented: $showingAPIKeyAlert) {
            TextField(L10n.apiKeyPlaceholder, text: $apiKeyInput)
            Button(L10n.save) {
                Config.setOpenAIAPIKey(apiKeyInput)
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(l10n.currentLanguage == .hebrew ? "הזן את מפתח ה-API של OpenAI כדי להפעיל תכונות קוליות" : "Enter your OpenAI API key to enable voice features.")
        }
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TimeTracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(L10n.voiceCoach)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            
            Spacer()
            
            Menu {
                Button(L10n.settings) {
                    showingSettings = true
                }
                Button(L10n.setAPIKey) {
                    showingAPIKeyAlert = true
                }
                Button(L10n.signOut, role: .destructive) {
                    authManager.signOut()
                }
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isConversationActive ? "🎙️ \(L10n.speakNaturally)" : "💡 \(L10n.trySaying)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748b"))
            
            if isConversationActive {
                Text(L10n.aiWillRespond)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "475569"))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \(L10n.tipWhatToday)")
                    Text("• \(L10n.tipWhatYesterday)")
                    Text("• \(L10n.tipAddGym)")
                    Text("• \(L10n.tipHowManyContacts)")
                    Text("• \(L10n.tipAddMom)")
                }
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "475569"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if !realtimeClient.isConnected && isConversationActive {
            return "Connecting..."
        }
        return realtimeClient.voiceState.statusText
    }
    
    // MARK: - Actions
    
    private func toggleConversation() {
        if isConversationActive {
            realtimeClient.stopConversation()
            isConversationActive = false
        } else {
            // With ephemeral tokens configured, no on-device key is needed.
            if !Config.usesEphemeralRealtimeToken && Config.openAIAPIKey.isEmpty {
                showingAPIKeyAlert = true
                return
            }
            realtimeClient.startConversation()
            isConversationActive = true
        }
    }

    private func checkAPIKey() {
        // Only prompt for a key in legacy (non-ephemeral) mode.
        if !Config.usesEphemeralRealtimeToken && Config.openAIAPIKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingAPIKeyAlert = true
            }
        }
    }
    
    private func loadData() {
        Task {
            await taskManager.fetchTasks()
            await taskManager.fetchCategories()
            await PeopleManager.shared.fetchPeople()
        }
    }
}

#Preview {
    VoiceView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
        .environmentObject(PeopleManager.shared)
}

