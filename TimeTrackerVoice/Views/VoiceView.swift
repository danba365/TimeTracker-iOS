import SwiftUI

/// Main voice interface view
struct VoiceView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var realtimeClient = RealtimeAPIClient.shared
    @StateObject private var audioManager = AudioStreamManager.shared
    
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
        .alert("OpenAI API Key Required", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKeyInput)
            Button("Save") {
                Config.setOpenAIAPIKey(apiKeyInput)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your OpenAI API key to enable voice features.")
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TimeTracker")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Voice Coach")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            
            Spacer()
            
            Menu {
                Button("Settings") {
                    showingSettings = true
                }
                Button("Set API Key") {
                    showingAPIKeyAlert = true
                }
                Button("Sign Out", role: .destructive) {
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
            Text(isConversationActive ? "🎙️ Speak naturally" : "💡 Try saying:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "64748b"))
            
            if isConversationActive {
                Text("The AI will respond when you pause speaking")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "475569"))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("• \"What's on my schedule today?\"")
                    Text("• \"Add gym tomorrow at 7am\"")
                    Text("• \"Mark today's meeting as done\"")
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
            if Config.openAIAPIKey.isEmpty {
                showingAPIKeyAlert = true
                return
            }
            realtimeClient.startConversation()
            isConversationActive = true
        }
    }
    
    private func checkAPIKey() {
        if Config.openAIAPIKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingAPIKeyAlert = true
            }
        }
    }
    
    private func loadData() {
        Task {
            await taskManager.fetchTasks()
            await taskManager.fetchCategories()
        }
    }
}

#Preview {
    VoiceView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
}

