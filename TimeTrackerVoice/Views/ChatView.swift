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
            // Background - tap to dismiss keyboard
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
            .onTapGesture {
                // Dismiss keyboard when tapping background
                isInputFocused = false
            }
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Messages
                messagesView
                    .onTapGesture {
                        // Dismiss keyboard when tapping messages area
                        isInputFocused = false
                    }
                
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
    
    // MARK: - Input (WhatsApp-style)
    
    private var inputView: some View {
        VStack(spacing: 0) {
            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Text input box - WhatsApp style with visible text
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "2d2d44"))
                    
                    // Border
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isInputFocused ? Color(hex: "a78bfa") : Color(hex: "4a4a6a"), lineWidth: 2)
                    
                    // Placeholder (only when empty)
                    if messageText.isEmpty {
                        Text(L10n.shared.typeMessagePlaceholder)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "64748b"))
                            .padding(.horizontal, 16)
                    }
                    
                    // TextField with visible white text
                    TextField("", text: $messageText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                        .tint(.white)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .submitLabel(.send)
                        .onSubmit {
                            sendCurrentMessage()
                        }
                }
                .frame(height: 48)
                
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
    
    // Conversation history for API
    private var conversationHistory: [[String: Any]] = []
    
    func sendMessage(_ text: String, tasks: [TaskItem]) {
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Check API key
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
        
        // Build task context
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
        
        // Add user message to history
        conversationHistory.append(["role": "user", "content": message])
        
        // Build messages array
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
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageData = firstChoice["message"] as? [String: Any] else {
            throw NSError(domain: "ChatManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // Check for tool calls
        if let toolCalls = messageData["tool_calls"] as? [[String: Any]] {
            // Execute tool calls
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
            
            // Add assistant message with tool calls to history
            conversationHistory.append(messageData)
            
            // Add tool results to history
            for result in toolResults {
                conversationHistory.append(result)
            }
            
            // Make another API call to get final response
            return try await getFinalResponse(systemPrompt: systemPrompt)
        }
        
        // No tool calls - return content directly
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
        
        // Get user ID from AuthManager
        guard let userId = AuthManager.shared.currentUser?.id else {
            return isHebrew ? "❌ לא מחובר - אנא התחבר מחדש" : "❌ Not authenticated - please log in again"
        }
        
        var input = CreateTaskInput(
            title: title,
            date: date
        )
        input.userId = userId  // Set the user_id for Supabase RLS
        input.startTime = args["start_time"] as? String
        input.endTime = args["end_time"] as? String
        if let notes = args["notes"] as? String {
            input.description = notes
        }
        
        do {
            let task = try await taskManager.createTask(input)
            // Refresh tasks to show the new task in the list
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
        
        // Add contacts count
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

