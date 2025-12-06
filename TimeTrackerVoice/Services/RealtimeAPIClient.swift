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
        let context = buildTaskContext()
        
        let config: [String: Any] = [
            "type": "session.update",
            "session": [
                "modalities": ["text", "audio"],
                "instructions": """
                You are a friendly AI voice assistant for TimeTracker, a task management app.
                You help users manage their schedule through natural voice conversation.
                
                Your capabilities:
                - View tasks for any date
                - Create new tasks
                - Update existing tasks (mark complete, change time, etc.)
                - Delete tasks
                
                Be conversational and natural. Confirm actions briefly.
                Keep responses concise - this is voice, not text.
                
                CURRENT CONTEXT:
                \(context)
                """,
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
    
    private func buildTaskContext() -> String {
        let taskManager = TaskManager.shared
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        let todaysTasks = taskManager.getTodaysTasks()
        let upcomingTasks = taskManager.getUpcomingTasks(days: 7)
        
        var context = "Today is \(today).\n\n"
        
        if !todaysTasks.isEmpty {
            context += "TODAY'S TASKS:\n"
            for task in todaysTasks {
                let emoji = task.status == .done ? "✅" : task.status == .missed ? "❌" : "⏳"
                let time = task.startTime.map { " at \($0)" } ?? ""
                context += "\(emoji) \(task.title)\(time)\n"
            }
            context += "\n"
        } else {
            context += "No tasks scheduled for today.\n\n"
        }
        
        let futureTasks = upcomingTasks.filter { $0.date != today }
        if !futureTasks.isEmpty {
            context += "UPCOMING TASKS:\n"
            for task in futureTasks.prefix(10) {
                let emoji = task.status == .done ? "✅" : "⏳"
                context += "\(emoji) \(task.title) (\(task.date))\n"
            }
        }
        
        return context
    }
    
    private func getFunctionTools() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "name": "get_tasks",
                "description": "Get tasks for a specific date or date range",
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
            ]
        ]
    }
    
    // MARK: - Audio Streaming
    
    func startConversation() {
        if !isConnected {
            connect()
            // Wait for connection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.audioManager.startRecording()
            }
        } else {
            audioManager.startRecording()
        }
        voiceState = .listening
    }
    
    func stopConversation() {
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
                voiceState = .speaking
                audioManager.queueAudio(audioData)
                onResponseAudio?(audioData)
            }
            
        case "response.audio.done":
            print("🔊 Audio response complete")
            
        case "response.function_call_arguments.done":
            handleFunctionCall(json)
            
        case "response.done":
            print("✅ Response complete")
            voiceState = .listening
            onResponseComplete?()
            lastResponse = ""
            
            // Refresh task data
            Task {
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
            
            let input = CreateTaskInput(
                title: title,
                date: date,
                startTime: args["start_time"] as? String,
                priority: Priority(rawValue: args["priority"] as? String ?? "medium") ?? .medium
            )
            
            do {
                let task = try await taskManager.createTask(input)
                let time = task.startTime.map { " at \($0)" } ?? ""
                return "Created task: \(task.title) for \(task.date)\(time)"
            } catch {
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

