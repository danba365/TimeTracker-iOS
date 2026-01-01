import SwiftUI

/// Text-based AI chat view
struct ChatView: View {
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var chatManager = ChatManager()
    
    @State private var messageText = ""
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    @FocusState private var isInputFocused: Bool
    
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
                
                // Input
                inputView
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
                Text("AI Assistant")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Ask me about your tasks")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Spacer()
            
            Menu {
                Button("Set API Key") {
                    showingAPIKeyAlert = true
                }
                Button("Clear Chat", role: .destructive) {
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
        VStack(spacing: 20) {
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "a78bfa"))
            
            Text("How can I help you?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                SuggestionButton(text: "What's on my schedule today?") {
                    sendMessage("What's on my schedule today?")
                }
                SuggestionButton(text: "Add a meeting tomorrow at 10am") {
                    sendMessage("Add a meeting tomorrow at 10am")
                }
                SuggestionButton(text: "Show me my high priority tasks") {
                    sendMessage("Show me my high priority tasks")
                }
            }
        }
        .padding(.top, 40)
    }
    
    // MARK: - Input
    
    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(ChatTextFieldStyle())
                .focused($isInputFocused)
                .onSubmit {
                    sendCurrentMessage()
                }
            
            Button(action: sendCurrentMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(messageText.isEmpty ? Color(hex: "475569") : Color(hex: "a78bfa"))
            }
            .disabled(messageText.isEmpty || chatManager.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(message.role == .user ? .white : Color(hex: "e2e8f0"))
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

// MARK: - Chat Text Field Style

struct ChatTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(20)
            .foregroundColor(.white)
    }
}

#Preview {
    ChatView()
        .environmentObject(TaskManager.shared)
}

