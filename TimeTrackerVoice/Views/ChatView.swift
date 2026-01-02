import SwiftUI

/// Text-based AI chat view with Hebrew RTL support
struct ChatView: View {
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var chatManager = ChatManager()
    
    @State private var messageText = ""
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    @FocusState private var isInputFocused: Bool
    
    // Detect if text is RTL (Hebrew/Arabic)
    private var isRTL: Bool {
        guard let firstChar = messageText.first else { return false }
        let language = CFStringTokenizerCopyBestStringLanguage(messageText as CFString, CFRange(location: 0, length: messageText.count))
        return language as String? == "he" || language as String? == "ar" || firstChar.isHebrewOrArabic
    }
    
    var body: some View {
        ZStack {
            // Background
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
                
                // Messages
                messagesView
                
                // Input - with extra padding for tab bar
                inputView
                
                // Space for tab bar (approximately 80 points)
                Color.clear
                    .frame(height: 80)
            }
        }
        .onAppear {
            checkAPIKey()
        }
        .alert("OpenAI API Key", isPresented: $showingAPIKeyAlert) {
            TextField("API Key", text: $apiKeyInput)
            Button("Save") {
                Config.setOpenAIAPIKey(apiKeyInput)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your OpenAI API key to enable AI chat features.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.aiAssistant)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(L10n.askMeAboutTasks)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Spacer()
            
            Menu {
                Button(L10n.setAPIKey) {
                    showingAPIKeyAlert = true
                }
                Button(L10n.clearChat, role: .destructive) {
                    chatManager.clearMessages()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Messages
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if chatManager.messages.isEmpty {
                        welcomeView
                    } else {
                        ForEach(chatManager.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if chatManager.isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .refreshable {
                // Refresh tasks data for chat context
                await taskManager.fetchTasks()
            }
            .onChange(of: chatManager.messages.count) { _, _ in
                if let lastMessage = chatManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "a78bfa"))
            
            Text(L10n.howCanIHelp)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Quick suggestions in a horizontal scroll
            Text("💡 דוגמאות:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "64748b"))
                .padding(.top, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SuggestionButton(text: L10n.suggestionWhatToday) {
                        sendMessage(L10n.suggestionWhatToday)
                    }
                    SuggestionButton(text: L10n.suggestionAddTask) {
                        sendMessage(L10n.suggestionAddTaskFull)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Hint to type
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                Text(L10n.typeMessageHint)
                    .font(.system(size: 14))
            }
            .foregroundColor(Color(hex: "64748b"))
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Input (ChatGPT-style)
    
    private var inputView: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Text input box - SIMPLE AND VISIBLE
                ZStack(alignment: .leading) {
                    // Placeholder
                    if messageText.isEmpty {
                        Text(L10n.typeMessagePlaceholder)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "64748b"))
                            .padding(.horizontal, 16)
                    }
                    
                    // Actual TextField
                    TextField("", text: $messageText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .submitLabel(.send)
                        .onSubmit {
                            sendCurrentMessage()
                        }
                }
                .frame(height: 48)
                .background(Color(hex: "2d2d44"))
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isInputFocused ? Color(hex: "a78bfa") : Color(hex: "4a4a6a"), lineWidth: 2)
                )
                
                // Send button
                Button(action: sendCurrentMessage) {
                    ZStack {
                        Circle()
                            .fill(messageText.isEmpty ? Color(hex: "3d3d5c") : Color(hex: "a78bfa"))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(messageText.isEmpty || chatManager.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8) // Extra padding for tab bar
        }
        .background(Color(hex: "1a1a2e"))
    }
    
    // MARK: - Actions
    
    private func checkAPIKey() {
        if Config.openAIAPIKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showingAPIKeyAlert = true
            }
        }
    }
    
    private func sendCurrentMessage() {
        guard !messageText.isEmpty else { return }
        sendMessage(messageText)
        messageText = ""
    }
    
    private func sendMessage(_ text: String) {
        let tasks = taskManager.tasks
        chatManager.sendMessage(text, tasks: tasks)
    }
}

// MARK: - Chat Manager

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    func sendMessage(_ text: String, tasks: [TaskItem]) {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Check API key
        guard !Config.openAIAPIKey.isEmpty else {
            let errorMessage = ChatMessage(role: .assistant, content: "Please set your OpenAI API key in settings to use the chat feature.")
            messages.append(errorMessage)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response = try await callOpenAI(message: text, tasks: tasks)
                let assistantMessage = ChatMessage(role: .assistant, content: response)
                messages.append(assistantMessage)
            } catch {
                let errorMessage = ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)")
                messages.append(errorMessage)
            }
            isLoading = false
        }
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    private func callOpenAI(message: String, tasks: [TaskItem]) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Build task context
        let taskContext = buildTaskContext(tasks: tasks)
        
        let systemPrompt = """
        You are a helpful AI assistant for TimeTracker, a task management app.
        Help users manage their tasks and schedule.
        Be concise and friendly.
        
        Current date: \(Date().formatted(date: .complete, time: .omitted))
        
        USER'S TASKS:
        \(taskContext)
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return response.choices.first?.message.content ?? "No response"
    }
    
    private func buildTaskContext(tasks: [TaskItem]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        let todayTasks = tasks.filter { $0.date == today }
        let upcomingTasks = tasks.filter { $0.date > today }.prefix(10)
        
        var context = "TODAY'S TASKS:\n"
        if todayTasks.isEmpty {
            context += "No tasks scheduled for today.\n"
        } else {
            for task in todayTasks {
                let emoji = task.status == .done ? "✅" : "⏳"
                let time = task.startTime.map { " at \($0)" } ?? ""
                context += "\(emoji) \(task.title)\(time) - \(task.status.rawValue)\n"
            }
        }
        
        context += "\nUPCOMING TASKS:\n"
        for task in upcomingTasks {
            context += "• \(task.title) (\(task.date))\n"
        }
        
        return context
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()
    
    enum MessageRole {
        case user, assistant
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    // Detect if message content is RTL (Hebrew/Arabic)
    private var isRTL: Bool {
        guard let firstChar = message.content.first else { return false }
        let language = CFStringTokenizerCopyBestStringLanguage(message.content as CFString, CFRange(location: 0, length: message.content.count))
        return language as String? == "he" || language as String? == "ar" || firstChar.isHebrewOrArabic
    }
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(message.role == .user ? .white : Color(hex: "e2e8f0"))
                .multilineTextAlignment(isRTL ? .trailing : .leading)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.role == .user ? Color(hex: "7c3aed") : Color.white.opacity(0.1))
                )
            
            if message.role == .assistant { Spacer() }
        }
    }
}

// MARK: - Suggestion Button

struct SuggestionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "a78bfa"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "a78bfa").opacity(0.1))
                .cornerRadius(20)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hex: "94a3b8"))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .onAppear { animating = true }
    }
}


// MARK: - Character Extension for RTL Detection

extension Character {
    var isHebrewOrArabic: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        // Hebrew: 0x0590–0x05FF, Arabic: 0x0600–0x06FF
        return (value >= 0x0590 && value <= 0x05FF) || (value >= 0x0600 && value <= 0x06FF)
    }
}

#Preview {
    ChatView()
        .environmentObject(TaskManager.shared)
}

