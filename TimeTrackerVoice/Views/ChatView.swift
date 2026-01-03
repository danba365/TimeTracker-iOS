import SwiftUI

/// ChatGPT-style AI chat view with Hebrew RTL support
struct ChatView: View {
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var chatManager = ChatManager()
    
    @State private var messageText = ""
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    @State private var textEditorHeight: CGFloat = 44
    @FocusState private var isInputFocused: Bool
    
    private let maxTextEditorHeight: CGFloat = 120
    private let minTextEditorHeight: CGFloat = 44
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "0f0f0f")
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Header
                    chatHeader
                    
                    // Messages or Welcome
                    if chatManager.messages.isEmpty {
                        welcomeScreen
                    } else {
                        messagesScrollView
                    }
                    
                    // Input area
                    inputArea
                    
                    // Tab bar spacer
                    Color.clear.frame(height: 80)
                }
            }
        }
        .onAppear {
            if Config.openAIAPIKey.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showingAPIKeyAlert = true
                }
            }
        }
        .alert(L10n.shared.enterAPIKey, isPresented: $showingAPIKeyAlert) {
            TextField(L10n.shared.apiKeyPlaceholder, text: $apiKeyInput)
            Button(L10n.shared.save) {
                Config.setOpenAIAPIKey(apiKeyInput)
            }
            Button(L10n.shared.cancel, role: .cancel) {}
        } message: {
            Text(L10n.shared.currentLanguage == .hebrew 
                 ? "הזן את מפתח ה-API של OpenAI כדי להפעיל תכונות AI"
                 : "Enter your OpenAI API key to enable AI features")
        }
    }
    
    // MARK: - Header (Minimal ChatGPT-style)
    
    private var chatHeader: some View {
        HStack {
            // AI Model indicator
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "10a37f"))
                
                Text("GPT-4o")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "8e8ea0"))
            }
            
            Spacer()
            
            // Menu button
            Menu {
                Button(action: { showingAPIKeyAlert = true }) {
                    Label(L10n.shared.setAPIKey, systemImage: "key")
                }
                Button(role: .destructive, action: { chatManager.clearMessages() }) {
                    Label(L10n.shared.clearChat, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "8e8ea0"))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "0f0f0f"))
    }
    
    // MARK: - Welcome Screen (ChatGPT-style)
    
    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 60)
                
                // Logo
                ZStack {
                    Circle()
                        .fill(Color(hex: "10a37f"))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Title
                Text(L10n.shared.howCanIHelp)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Suggestion cards
                VStack(spacing: 12) {
                    suggestionCard(
                        icon: "calendar",
                        title: L10n.shared.suggestionWhatToday,
                        action: { sendMessage(L10n.shared.suggestionWhatToday) }
                    )
                    
                    suggestionCard(
                        icon: "plus.circle",
                        title: L10n.shared.suggestionAddTask,
                        action: { sendMessage(L10n.shared.suggestionAddTaskFull) }
                    )
                    
                    suggestionCard(
                        icon: "person.2",
                        title: L10n.shared.currentLanguage == .hebrew ? "מי באנשי הקשר שלי?" : "Who's in my contacts?",
                        action: { sendMessage(L10n.shared.currentLanguage == .hebrew ? "מי באנשי הקשר שלי?" : "Who's in my contacts?") }
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    private func suggestionCard(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "8e8ea0"))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "8e8ea0"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1a1a1a"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "2f2f2f"), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Messages (ChatGPT-style)
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(chatManager.messages) { message in
                        ChatGPTMessageRow(message: message)
                            .id(message.id)
                    }
                    
                    if chatManager.isLoading {
                        ChatGPTTypingRow()
                            .id("typing")
                    }
                }
                .padding(.bottom, 20)
            }
            .onChange(of: chatManager.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: chatManager.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onTapGesture {
                isInputFocused = false
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                if chatManager.isLoading {
                    proxy.scrollTo("typing", anchor: .bottom)
                } else if let lastMessage = chatManager.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Input Area (ChatGPT-style)
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                // Text input with auto-grow
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "1a1a1a"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(hex: "2f2f2f"), lineWidth: 1)
                        )
                    
                    // Placeholder
                    if messageText.isEmpty {
                        Text(L10n.shared.typeMessagePlaceholder)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "8e8ea0"))
                            .padding(.horizontal, 20)
                    }
                    
                    // TextField
                    TextField("", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                        .tint(Color(hex: "10a37f"))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .submitLabel(.send)
                        .onSubmit {
                            sendCurrentMessage()
                        }
                }
                .frame(minHeight: 48)
                
                // Send button
                Button(action: sendCurrentMessage) {
                    ZStack {
                        Circle()
                            .fill(messageText.isEmpty || chatManager.isLoading
                                  ? Color(hex: "2f2f2f")
                                  : Color(hex: "10a37f"))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(messageText.isEmpty || chatManager.isLoading
                                             ? Color(hex: "8e8ea0")
                                             : .white)
                    }
                }
                .disabled(messageText.isEmpty || chatManager.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(hex: "0f0f0f"))
    }
    
    // MARK: - Actions
    
    private func sendCurrentMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        sendMessage(text)
    }
    
    private func sendMessage(_ text: String) {
        chatManager.sendMessage(text, tasks: taskManager.tasks)
    }
}

// MARK: - ChatGPT Message Row

struct ChatGPTMessageRow: View {
    let message: ChatMessage
    
    private var isRTL: Bool {
        guard let firstChar = message.content.first else { return false }
        return firstChar.isHebrewOrArabic
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(Color(hex: "10a37f"))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Role label
                Text(message.role == .user
                     ? (L10n.shared.currentLanguage == .hebrew ? "אתה" : "You")
                     : "ChatGPT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Message content
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "d1d5db"))
                    .multilineTextAlignment(isRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(Color(hex: "5436da"))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(message.role == .assistant ? Color(hex: "1a1a1a") : Color.clear)
    }
}

// MARK: - Typing Indicator (ChatGPT-style)

struct ChatGPTTypingRow: View {
    @State private var dotScale: [CGFloat] = [0.5, 0.5, 0.5]
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "10a37f"))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ChatGPT")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(hex: "8e8ea0"))
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScale[index])
                    }
                }
                .onAppear {
                    animateDots()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(hex: "1a1a1a"))
    }
    
    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotScale[i] = 1.0
            }
        }
    }
}

// MARK: - Chat Manager (unchanged functionality)

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    private var conversationHistory: [[String: Any]] = []
    
    func sendMessage(_ text: String, tasks: [TaskItem]) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        guard !Config.openAIAPIKey.isEmpty else {
            let errorMessage = ChatMessage(role: .assistant, content: L10n.shared.currentLanguage == .hebrew 
                ? "אנא הגדר את מפתח ה-API של OpenAI בהגדרות" 
                : "Please set your OpenAI API key in settings to use the chat feature.")
            messages.append(errorMessage)
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response = try await callOpenAIWithTools(message: text, tasks: tasks)
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
        conversationHistory.removeAll()
    }
    
    // MARK: - Tool Definitions
    
    private func getTools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "get_tasks",
                    "description": "Get tasks for a specific date or date range",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "start_date": ["type": "string", "description": "Start date in YYYY-MM-DD format"],
                            "end_date": ["type": "string", "description": "End date in YYYY-MM-DD format (optional)"]
                        ],
                        "required": ["start_date"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_task",
                    "description": "Create a new task",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Task title"],
                            "date": ["type": "string", "description": "Date in YYYY-MM-DD format"],
                            "start_time": ["type": "string", "description": "Start time in HH:MM format (optional)"],
                            "end_time": ["type": "string", "description": "End time in HH:MM format (optional)"],
                            "notes": ["type": "string", "description": "Additional notes (optional)"]
                        ],
                        "required": ["title", "date"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "get_contacts",
                    "description": "Get list of contacts, optionally filtered by relationship type",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "relationship_type": [
                                "type": "string",
                                "enum": ["family", "friend", "colleague", "other", "all"],
                                "description": "Filter by relationship type"
                            ]
                        ],
                        "required": []
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_contact",
                    "description": "Create a new contact",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "first_name": ["type": "string", "description": "First name"],
                            "last_name": ["type": "string", "description": "Last name (optional)"],
                            "relationship_type": [
                                "type": "string",
                                "enum": ["family", "friend", "colleague", "other"],
                                "description": "Relationship type"
                            ],
                            "phone": ["type": "string", "description": "Phone number (optional)"],
                            "email": ["type": "string", "description": "Email address (optional)"]
                        ],
                        "required": ["first_name", "relationship_type"]
                    ]
                ]
            ]
        ]
    }
    
    // MARK: - API Call with Tools
    
    private func callOpenAIWithTools(message: String, tasks: [TaskItem]) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let taskContext = buildTaskContext(tasks: tasks)
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        
        let systemPrompt = isHebrew ? """
        אתה עוזר AI ידידותי לאפליקציית TimeTracker. עזור למשתמשים לנהל משימות ואנשי קשר.
        היה תמציתי וידידותי. דבר בעברית.
        
        תאריך נוכחי: \(Date().formatted(date: .complete, time: .omitted))
        
        יש לך גישה לכלים הבאים:
        - get_tasks: קבל משימות לתאריך או טווח תאריכים
        - create_task: צור משימה חדשה
        - get_contacts: קבל רשימת אנשי קשר
        - create_contact: צור איש קשר חדש
        
        השתמש בכלים אלה כאשר המשתמש מבקש לבצע פעולות!
        
        הקשר המשימות הנוכחי:
        \(taskContext)
        """ : """
        You are a helpful AI assistant for TimeTracker. Help users manage tasks and contacts.
        Be concise and friendly.
        
        Current date: \(Date().formatted(date: .complete, time: .omitted))
        
        You have access to these tools:
        - get_tasks: Get tasks for a date or date range
        - create_task: Create a new task
        - get_contacts: Get list of contacts
        - create_contact: Create a new contact
        
        Use these tools when the user asks to perform actions!
        
        Current task context:
        \(taskContext)
        """
        
        conversationHistory.append(["role": "user", "content": message])
        
        var messagesArray: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        messagesArray.append(contentsOf: conversationHistory)
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messagesArray,
            "tools": getTools(),
            "tool_choice": "auto",
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageData = firstChoice["message"] as? [String: Any] else {
            throw NSError(domain: "ChatManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if let toolCalls = messageData["tool_calls"] as? [[String: Any]] {
            var toolResults: [[String: Any]] = []
            
            for toolCall in toolCalls {
                guard let id = toolCall["id"] as? String,
                      let function = toolCall["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argsString = function["arguments"] as? String,
                      let argsData = argsString.data(using: .utf8),
                      let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                    continue
                }
                
                let result = await executeToolCall(name: name, args: args)
                toolResults.append([
                    "role": "tool",
                    "tool_call_id": id,
                    "content": result
                ])
            }
            
            conversationHistory.append(messageData)
            
            for result in toolResults {
                conversationHistory.append(result)
            }
            
            return try await getFinalResponse(systemPrompt: systemPrompt)
        }
        
        if let content = messageData["content"] as? String {
            conversationHistory.append(["role": "assistant", "content": content])
            return content
        }
        
        return isHebrew ? "לא הצלחתי להבין את הבקשה" : "I couldn't understand the request"
    }
    
    private func getFinalResponse(systemPrompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        var messagesArray: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        messagesArray.append(contentsOf: conversationHistory)
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messagesArray,
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "ChatManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        conversationHistory.append(["role": "assistant", "content": content])
        return content
    }
    
    // MARK: - Tool Execution
    
    private func executeToolCall(name: String, args: [String: Any]) async -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        
        switch name {
        case "get_tasks":
            return await executeGetTasks(args: args)
        case "create_task":
            return await executeCreateTask(args: args)
        case "get_contacts":
            return await executeGetContacts(args: args)
        case "create_contact":
            return await executeCreateContact(args: args)
        default:
            return isHebrew ? "פונקציה לא מוכרת" : "Unknown function"
        }
    }
    
    private func executeGetTasks(args: [String: Any]) async -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        let taskManager = TaskManager.shared
        
        guard let startDate = args["start_date"] as? String else {
            return isHebrew ? "חסר תאריך" : "Missing date"
        }
        
        let endDate = args["end_date"] as? String ?? startDate
        let tasks = taskManager.getTasksInRange(startDate: startDate, endDate: endDate)
        
        if tasks.isEmpty {
            return isHebrew ? "אין משימות בתאריכים אלו" : "No tasks found for these dates"
        }
        
        var result = isHebrew ? "משימות:\n" : "Tasks:\n"
        for task in tasks {
            let emoji = task.status == TaskStatus.done ? "✅" : "⏳"
            let time = task.startTime.map { " ב-\($0)" } ?? ""
            result += "\(emoji) \(task.title) (\(task.date))\(time)\n"
        }
        
        return result
    }
    
    private func executeCreateTask(args: [String: Any]) async -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        let taskManager = TaskManager.shared
        
        guard let title = args["title"] as? String,
              let date = args["date"] as? String else {
            return isHebrew ? "חסרים פרטי משימה" : "Missing task details"
        }
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            return isHebrew ? "❌ לא מחובר - אנא התחבר מחדש" : "❌ Not authenticated - please log in again"
        }
        
        var input = CreateTaskInput(title: title, date: date)
        input.userId = userId
        input.startTime = args["start_time"] as? String
        input.endTime = args["end_time"] as? String
        if let notes = args["notes"] as? String {
            input.description = notes
        }
        
        do {
            let task = try await taskManager.createTask(input)
            await taskManager.fetchTasks()
            return isHebrew 
                ? "✅ המשימה '\(task.title)' נוצרה בהצלחה לתאריך \(task.date)"
                : "✅ Task '\(task.title)' created successfully for \(task.date)"
        } catch {
            print("❌ Create task error: \(error)")
            return isHebrew ? "❌ שגיאה: \(error.localizedDescription)" : "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func executeGetContacts(args: [String: Any]) async -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        let peopleManager = PeopleManager.shared
        
        let filterTypeStr = args["relationship_type"] as? String ?? "all"
        
        var people = peopleManager.people
        if filterTypeStr != "all", let filterType = RelationshipType(rawValue: filterTypeStr) {
            people = peopleManager.getPeopleByType(filterType)
        }
        
        if people.isEmpty {
            return isHebrew ? "לא נמצאו אנשי קשר" : "No contacts found"
        }
        
        var result = isHebrew ? "אנשי קשר (\(people.count)):\n" : "Contacts (\(people.count)):\n"
        for person in people.prefix(15) {
            let name = [person.firstName, person.lastName].compactMap { $0 }.joined(separator: " ")
            let type = person.relationshipType.rawValue
            result += "• \(name) [\(type)]\n"
        }
        
        return result
    }
    
    private func executeCreateContact(args: [String: Any]) async -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        let peopleManager = PeopleManager.shared
        
        guard let firstName = args["first_name"] as? String,
              let relationshipTypeStr = args["relationship_type"] as? String,
              let relationshipType = RelationshipType(rawValue: relationshipTypeStr) else {
            return isHebrew ? "חסרים פרטי איש קשר" : "Missing contact details"
        }
        
        let input = CreatePersonInput(
            firstName: firstName,
            lastName: args["last_name"] as? String,
            nickname: nil,
            relationshipType: relationshipType,
            relationshipDetail: nil,
            phone: args["phone"] as? String,
            email: args["email"] as? String,
            birthday: nil,
            notes: nil
        )
        
        do {
            let person = try await peopleManager.createPerson(input)
            let name = [person.firstName, person.lastName].compactMap { $0 }.joined(separator: " ")
            return isHebrew
                ? "✅ איש הקשר '\(name)' נוצר בהצלחה"
                : "✅ Contact '\(name)' created successfully"
        } catch {
            return isHebrew ? "❌ שגיאה: \(error.localizedDescription)" : "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func buildTaskContext(tasks: [TaskItem]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        
        let todayTasks = tasks.filter { $0.date == today }
        let upcomingTasks = tasks.filter { $0.date > today }.prefix(10)
        
        var context = isHebrew ? "משימות היום:\n" : "TODAY'S TASKS:\n"
        if todayTasks.isEmpty {
            context += isHebrew ? "אין משימות מתוכננות להיום.\n" : "No tasks scheduled for today.\n"
        } else {
            for task in todayTasks {
                let emoji = task.status == .done ? "✅" : "⏳"
                let time = task.startTime.map { " ב-\($0)" } ?? ""
                context += "\(emoji) \(task.title)\(time) - \(task.status.rawValue)\n"
            }
        }
        
        context += isHebrew ? "\nמשימות קרובות:\n" : "\nUPCOMING TASKS:\n"
        for task in upcomingTasks {
            context += "• \(task.title) (\(task.date))\n"
        }
        
        let contactsCount = PeopleManager.shared.people.count
        context += isHebrew ? "\nאנשי קשר: \(contactsCount)" : "\nContacts: \(contactsCount)"
        
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

// MARK: - Character Extension

extension Character {
    var isHebrewOrArabic: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        return (value >= 0x0590 && value <= 0x05FF) || (value >= 0x0600 && value <= 0x06FF)
    }
}

#Preview {
    ChatView()
        .environmentObject(TaskManager.shared)
}
