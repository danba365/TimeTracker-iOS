import Foundation
import Combine

/// OpenAI Realtime API WebSocket Client
/// Handles full-duplex voice conversation with the AI
class RealtimeAPIClient: NSObject, ObservableObject {
    static let shared = RealtimeAPIClient()
    
    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    // State
    @Published var isConnected = false
    @Published var voiceState: VoiceState = .idle
    @Published var lastTranscript = ""
    @Published var lastResponse = ""
    private var isConversationActive = false
    
    // Callbacks
    var onSpeechStarted: (() -> Void)?
    var onSpeechEnded: (() -> Void)?
    var onResponseAudio: ((Data) -> Void)?
    var onResponseText: ((String) -> Void)?
    var onFunctionCall: ((String, [String: Any]) async -> String)?
    var onResponseComplete: (() -> Void)?
    var onError: ((String) -> Void)?
    
    // Audio manager
    private let audioManager = AudioStreamManager.shared
    
    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        // Set up audio callback
        audioManager.onAudioChunk = { [weak self] data in
            self?.sendAudioChunk(data)
        }
    }
    
    // MARK: - Connection
    
    func connect() {
        guard !isConnected else { return }
        guard !Config.openAIAPIKey.isEmpty else {
            onError?("OpenAI API key not set")
            return
        }
        
        let urlString = "\(Config.openAIRealtimeURL)?model=\(Config.openAIRealtimeModel)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("realtime", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        webSocket = urlSession.webSocketTask(with: request)
        webSocket?.resume()
        
        print("🔌 Connecting to OpenAI Realtime API...")
        receiveMessage()
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        voiceState = .idle
        print("🔌 Disconnected")
    }
    
    // MARK: - Session Configuration
    
    private func configureSession() {
        Task { @MainActor in
            let context = buildTaskContext()
            sendSessionConfig(context: context)
        }
    }
    
    private func sendSessionConfig(context: String) {
        // Get current language from L10n
        let currentLang = L10n.shared.currentLanguage
        let promptManager = PromptManager.shared
        
        // Build instructions from prompts
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        dayFormatter.locale = currentLang == .hebrew ? Locale(identifier: "he") : Locale(identifier: "en")
        
        let dateContext = promptManager.getPromptWithVars(
            key: "date_context",
            language: currentLang,
            vars: [
                "date": dateFormatter.string(from: Date()),
                "day_name": dayFormatter.string(from: Date())
            ]
        )
        
        let systemInstructions = promptManager.getPrompt(key: "system_instructions", language: currentLang)
        let voiceBehavior = promptManager.getPrompt(key: "voice_behavior", language: currentLang)
        
        let fullInstructions = """
        \(systemInstructions)
        
        \(dateContext)
        
        \(voiceBehavior)
        
        CURRENT CONTEXT:
        \(context)
        """
        
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": fullInstructions,
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": [
                    "model": "whisper-1"
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 700
                ],
                "tools": getFunctionTools()
            ]
        ]
        
        sendMessage(config)
    }
    
    @MainActor
    private func buildTaskContext() -> String {
        let taskManager = TaskManager.shared
        let peopleManager = PeopleManager.shared
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let today = formatter.string(from: now)
        let yesterday = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: now)!)
        
        let todaysTasks = taskManager.getTodaysTasks()
        let upcomingTasks = taskManager.getUpcomingTasks(days: 7)
        let yesterdayTasks = taskManager.getTasksByDate(yesterday)
        
        var context = "Today is \(today).\n\n"
        
        // Yesterday's tasks (for reference)
        if !yesterdayTasks.isEmpty {
            context += "YESTERDAY'S TASKS (\(yesterday)):\n"
            for task in yesterdayTasks {
                let emoji = task.status == .done ? "✅" : task.status == .missed ? "❌" : "⏳"
                let time = task.startTime.map { " at \($0)" } ?? ""
                context += "\(emoji) \(task.title)\(time) - \(task.status.rawValue)\n"
            }
            context += "\n"
        }
        
        // Today's tasks
        if !todaysTasks.isEmpty {
            context += "TODAY'S TASKS:\n"
            for task in todaysTasks {
                let emoji = task.status == .done ? "✅" : task.status == .missed ? "❌" : "⏳"
                let time = task.startTime.map { " at \($0)" } ?? ""
                context += "\(emoji) \(task.title)\(time) - \(task.status.rawValue)\n"
            }
            context += "\n"
        } else {
            context += "No tasks scheduled for today.\n\n"
        }
        
        // Upcoming tasks
        let futureTasks = upcomingTasks.filter { $0.date != today }
        if !futureTasks.isEmpty {
            context += "UPCOMING TASKS (Next 7 Days):\n"
            for task in futureTasks.prefix(10) {
                let emoji = task.status == .done ? "✅" : "⏳"
                context += "\(emoji) \(task.title) (\(task.date))\n"
            }
            context += "\n"
        }
        
        // Contacts summary
        let stats = peopleManager.stats
        if stats.total > 0 {
            context += "CONTACTS: \(stats.total) total"
            context += " (\(stats.family) family, \(stats.friends) friends, \(stats.colleagues) colleagues)\n"
            
            // Upcoming birthdays
            let upcomingBirthdays = peopleManager.getUpcomingBirthdays(days: 30)
            if !upcomingBirthdays.isEmpty {
                context += "Upcoming birthdays: "
                context += upcomingBirthdays.prefix(3).map { person in
                    "\(person.displayName) in \(person.daysUntilBirthday ?? 0) days"
                }.joined(separator: ", ")
                context += "\n"
            }
        }
        
        // Instructions for past dates
        context += "\nIMPORTANT: For tasks on specific dates (past or future), ALWAYS use the get_tasks function with the date parameter.\n"
        
        return context
    }
    
    private func getFunctionTools() -> [[String: Any]] {
        return [
            // Task tools
            [
                "type": "function",
                "name": "get_tasks",
                "description": "Get tasks for a specific date or date range - ALWAYS use this when user asks about tasks on a specific date!",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "date": ["type": "string", "description": "Date in YYYY-MM-DD format"],
                        "start_date": ["type": "string", "description": "Start date for range"],
                        "end_date": ["type": "string", "description": "End date for range"]
                    ]
                ]
            ],
            [
                "type": "function",
                "name": "create_task",
                "description": "Create a new task",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Task title"],
                        "date": ["type": "string", "description": "Date in YYYY-MM-DD format"],
                        "start_time": ["type": "string", "description": "Start time in HH:MM format"],
                        "priority": ["type": "string", "enum": ["low", "medium", "high"]]
                    ],
                    "required": ["title", "date"]
                ]
            ],
            [
                "type": "function",
                "name": "update_task",
                "description": "Update an existing task",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "task_title": ["type": "string", "description": "Title of the task to update"],
                        "new_status": ["type": "string", "enum": ["todo", "in_progress", "done", "missed"]],
                        "new_title": ["type": "string"],
                        "new_date": ["type": "string"],
                        "new_start_time": ["type": "string"]
                    ]
                ]
            ],
            [
                "type": "function",
                "name": "delete_task",
                "description": "Delete a task",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "task_title": ["type": "string", "description": "Title of the task to delete"]
                    ]
                ]
            ],
            // Contact/People tools
            [
                "type": "function",
                "name": "get_contacts",
                "description": "Get list of contacts/people, optionally filtered by relationship type",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "relationship_type": [
                            "type": "string",
                            "enum": ["family", "friend", "colleague", "other", "all"],
                            "description": "Filter by relationship type: family, friend, colleague, other, or all"
                        ],
                        "include_birthdays": [
                            "type": "boolean",
                            "description": "Whether to include upcoming birthday information"
                        ]
                    ]
                ]
            ],
            [
                "type": "function",
                "name": "create_contact",
                "description": "Create a new contact/person",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "first_name": ["type": "string", "description": "First name"],
                        "last_name": ["type": "string", "description": "Last name (optional)"],
                        "nickname": ["type": "string", "description": "Nickname (optional)"],
                        "relationship_type": [
                            "type": "string",
                            "enum": ["family", "friend", "colleague", "other"],
                            "description": "Relationship type"
                        ],
                        "relationship_detail": ["type": "string", "description": "Specific relationship, e.g.: brother, mother, best friend, manager"],
                        "phone": ["type": "string", "description": "Phone number (optional)"],
                        "email": ["type": "string", "description": "Email address (optional)"],
                        "birthday": ["type": "string", "description": "Birthday in YYYY-MM-DD format (optional)"],
                        "notes": ["type": "string", "description": "Additional notes (optional)"]
                    ],
                    "required": ["first_name", "relationship_type"]
                ]
            ]
        ]
    }
    
    // MARK: - Audio Streaming
    
    func startConversation() {
        isConversationActive = true
        
        // Initialize prompts before starting conversation
        Task {
            await PromptManager.shared.initialize()
            
            await MainActor.run {
                if !self.isConnected {
                    self.connect()
                    // Wait for connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.audioManager.startRecording()
                        self?.voiceState = .listening
                    }
                } else {
                    self.audioManager.startRecording()
                    self.voiceState = .listening
                }
            }
        }
    }
    
    func stopConversation() {
        isConversationActive = false
        audioManager.stopRecording()
        audioManager.clearAudioQueue()
        voiceState = .idle
    }
    
    private func sendAudioChunk(_ data: Data) {
        guard isConnected else { return }
        
        let base64Audio = data.base64EncodedString()
        
        let message: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64Audio
        ]
        
        sendMessage(message)
    }
    
    // MARK: - WebSocket Communication
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("❌ Send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self?.receiveMessage()
                
            case .failure(let error):
                print("❌ Receive error: \(error)")
                self?.isConnected = false
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "session.created", "session.updated":
            print("✅ Session configured")
            if type == "session.created" {
                isConnected = true
                configureSession()
            }
            
        case "input_audio_buffer.speech_started":
            print("🎤 Speech detected")
            voiceState = .listening
            onSpeechStarted?()
            // Stop any playing audio (interruption)
            audioManager.clearAudioQueue()
            
        case "input_audio_buffer.speech_stopped":
            print("🔇 Speech ended")
            voiceState = .processing
            onSpeechEnded?()
            
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                lastResponse += delta
                onResponseText?(delta)
            }
            
        case "response.audio_transcript.done":
            if let transcript = json["transcript"] as? String {
                lastResponse = transcript
                print("📝 AI: \(transcript)")
            }
            
        case "response.audio.delta":
            if let delta = json["delta"] as? String,
               let audioData = Data(base64Encoded: delta) {
                // Stop recording while AI is speaking to prevent echo feedback
                if audioManager.isRecording {
                    audioManager.stopRecording()
                    print("⏸️ Paused recording (AI speaking)")
                }
                voiceState = .speaking
                audioManager.queueAudio(audioData)
                onResponseAudio?(audioData)
            }
            
        case "response.audio.done":
            print("🔊 Audio response complete")
            // Resume recording after AI finishes speaking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isConnected, self.isConversationActive else { return }
                if !self.audioManager.isRecording && !self.audioManager.isPlaying {
                    self.audioManager.startRecording()
                    self.voiceState = .listening
                    print("▶️ Resumed recording")
                }
            }
            
        case "response.function_call_arguments.done":
            handleFunctionCall(json)
            
        case "response.done":
            print("✅ Response complete")
            onResponseComplete?()
            lastResponse = ""
            
            // Resume recording after response is complete (with delay to let audio finish)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, self.isConnected, self.isConversationActive else { return }
                if !self.audioManager.isRecording {
                    self.audioManager.startRecording()
                    self.voiceState = .listening
                    print("▶️ Resumed recording after response")
                }
            }
            
            // Refresh task data (don't await, do it in background)
            Task.detached {
                await TaskManager.shared.fetchTasks()
            }
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ API Error: \(message)")
                onError?(message)
            }
            voiceState = .error
            
        default:
            break
        }
    }
    
    private func handleFunctionCall(_ json: [String: Any]) {
        guard let name = json["name"] as? String,
              let argsString = json["arguments"] as? String,
              let argsData = argsString.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
              let callId = json["call_id"] as? String else {
            return
        }
        
        print("🔧 Function call: \(name)")
        
        Task { @MainActor in
            let result = await executeFunctionCall(name: name, args: args)
            
            // Send result back
            let response: [String: Any] = [
                "type": "conversation.item.create",
                "item": [
                    "type": "function_call_output",
                    "call_id": callId,
                    "output": result
                ]
            ]
            sendMessage(response)
            
            // Request AI to respond
            sendMessage(["type": "response.create"])
        }
    }
    
    @MainActor
    private func executeFunctionCall(name: String, args: [String: Any]) async -> String {
        let taskManager = TaskManager.shared
        
        switch name {
        case "get_tasks":
            let date = args["date"] as? String
            let tasks = date != nil ? taskManager.getTasksByDate(date!) : taskManager.getTodaysTasks()
            
            if tasks.isEmpty {
                return "No tasks found for the specified date."
            }
            
            return tasks.map { task in
                let emoji = task.status == .done ? "✅" : task.status == .missed ? "❌" : "⏳"
                let time = task.startTime.map { " at \($0)" } ?? ""
                return "\(emoji) \(task.title)\(time) - \(task.status.rawValue)"
            }.joined(separator: "\n")
            
        case "create_task":
            guard let title = args["title"] as? String,
                  let date = args["date"] as? String else {
                return "Missing required fields: title and date"
            }
            
            // Get user ID from AuthManager
            guard let userId = AuthManager.shared.currentUser?.id else {
                return "Not authenticated - please log in again"
            }
            
            var input = CreateTaskInput(
                title: title,
                date: date,
                startTime: args["start_time"] as? String,
                priority: Priority(rawValue: args["priority"] as? String ?? "medium") ?? .medium
            )
            input.userId = userId  // Set the user_id for Supabase RLS
            
            do {
                let task = try await taskManager.createTask(input)
                // Refresh tasks to show the new task in the list
                await taskManager.fetchTasks()
                let time = task.startTime.map { " at \($0)" } ?? ""
                return "Created task: \(task.title) for \(task.date)\(time)"
            } catch {
                print("❌ Create task error: \(error)")
                return "Failed to create task: \(error.localizedDescription)"
            }
            
        case "update_task":
            guard let taskTitle = args["task_title"] as? String else {
                return "Please specify which task to update"
            }
            
            guard let task = taskManager.findTask(byTitle: taskTitle) else {
                return "Task not found: \(taskTitle)"
            }
            
            var updateInput = UpdateTaskInput()
            if let newStatus = args["new_status"] as? String {
                updateInput.status = TaskStatus(rawValue: newStatus)
            }
            if let newTitle = args["new_title"] as? String {
                updateInput.title = newTitle
            }
            if let newDate = args["new_date"] as? String {
                updateInput.date = newDate
            }
            if let newTime = args["new_start_time"] as? String {
                updateInput.startTime = newTime
            }
            
            do {
                let updated = try await taskManager.updateTask(id: task.id, input: updateInput)
                var changes = "Updated \(updated.title)"
                if let status = updateInput.status {
                    changes += " - status: \(status.rawValue)"
                }
                return changes
            } catch {
                return "Failed to update task: \(error.localizedDescription)"
            }
            
        case "delete_task":
            guard let taskTitle = args["task_title"] as? String else {
                return "Please specify which task to delete"
            }
            
            guard let task = taskManager.findTask(byTitle: taskTitle) else {
                return "Task not found: \(taskTitle)"
            }
            
            do {
                try await taskManager.deleteTask(id: task.id)
                return "Deleted task: \(task.title)"
            } catch {
                return "Failed to delete task: \(error.localizedDescription)"
            }
            
        // MARK: - Contact Tools
            
        case "get_contacts":
            let peopleManager = PeopleManager.shared
            let filterType = args["relationship_type"] as? String ?? "all"
            let includeBirthdays = args["include_birthdays"] as? Bool ?? false
            
            var filteredPeople = peopleManager.people
            if filterType != "all", let type = RelationshipType(rawValue: filterType) {
                filteredPeople = peopleManager.getPeopleByType(type)
            }
            
            if filteredPeople.isEmpty {
                return filterType != "all" 
                    ? "No contacts found of type \(filterType)"
                    : "No contacts found"
            }
            
            var result = "Contacts (\(filteredPeople.count)):\n"
            result += filteredPeople.map { person in
                var info = "• \(person.fullName) - \(person.relationshipType.rawValue)"
                if let detail = person.relationshipDetail {
                    info += " (\(detail))"
                }
                if includeBirthdays, let days = person.daysUntilBirthday {
                    info += " - Birthday in \(days) days"
                }
                return info
            }.joined(separator: "\n")
            
            if includeBirthdays {
                let upcoming = peopleManager.getUpcomingBirthdays(days: 30)
                if !upcoming.isEmpty {
                    result += "\n\nUpcoming Birthdays:\n"
                    result += upcoming.prefix(5).map { person in
                        "🎂 \(person.fullName) in \(person.daysUntilBirthday ?? 0) days"
                    }.joined(separator: "\n")
                }
            }
            
            return result
            
        case "create_contact":
            let peopleManager = PeopleManager.shared
            
            guard let firstName = args["first_name"] as? String,
                  let relationshipTypeStr = args["relationship_type"] as? String,
                  let relationshipType = RelationshipType(rawValue: relationshipTypeStr) else {
                return "Missing required fields: first_name and relationship_type"
            }
            
            // Get user ID for Supabase RLS
            guard let userId = AuthManager.shared.currentUser?.id else {
                return "Not authenticated - please log in again"
            }
            
            var input = CreatePersonInput(
                firstName: firstName,
                lastName: args["last_name"] as? String,
                nickname: args["nickname"] as? String,
                relationshipType: relationshipType,
                relationshipDetail: args["relationship_detail"] as? String,
                phone: args["phone"] as? String,
                email: args["email"] as? String,
                birthday: args["birthday"] as? String,
                notes: args["notes"] as? String
            )
            input.userId = userId  // Required for Supabase RLS
            
            do {
                let person = try await peopleManager.createPerson(input)
                await peopleManager.fetchPeople()  // Refresh contacts list
                let relationshipInfo = person.relationshipDetail ?? person.relationshipType.rawValue
                return "✅ Created contact: \(person.fullName) - \(relationshipInfo)"
            } catch {
                return "Failed to create contact: \(error.localizedDescription)"
            }
            
        default:
            return "Unknown function: \(name)"
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension RealtimeAPIClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket connected")
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 WebSocket closed: \(closeCode)")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

