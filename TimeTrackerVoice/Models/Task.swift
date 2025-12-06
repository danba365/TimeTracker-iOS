import Foundation

// MARK: - Task Models

enum Priority: String, Codable, CaseIterable {
    case low, medium, high
}

enum TaskStatus: String, Codable, CaseIterable {
    case todo, in_progress, done, missed
}

enum TaskType: String, Codable {
    case task, reminder
}

struct Task: Identifiable, Codable {
    let id: String
    var title: String
    var description: String?
    var date: String  // YYYY-MM-DD
    var startTime: String?  // HH:MM
    var endTime: String?
    var priority: Priority
    var status: TaskStatus
    var taskType: TaskType
    var categoryId: String?
    var tags: [String]
    var isRecurring: Bool
    var createdAt: String
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, date, priority, status, tags
        case startTime = "start_time"
        case endTime = "end_time"
        case taskType = "task_type"
        case categoryId = "category_id"
        case isRecurring = "is_recurring"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Category: Identifiable, Codable {
    let id: String
    var key: String?
    var name: String
    var color: String
    var icon: String?
    var createdAt: String
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, key, name, color, icon
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Create/Update Inputs

struct CreateTaskInput: Codable {
    var title: String
    var description: String?
    var date: String
    var startTime: String?
    var endTime: String?
    var priority: Priority = .medium
    var status: TaskStatus = .todo
    var taskType: TaskType = .task
    var categoryId: String?
    var tags: [String] = []
    var isRecurring: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case title, description, date, priority, status, tags
        case startTime = "start_time"
        case endTime = "end_time"
        case taskType = "task_type"
        case categoryId = "category_id"
        case isRecurring = "is_recurring"
    }
}

struct UpdateTaskInput: Codable {
    var title: String?
    var description: String?
    var date: String?
    var startTime: String?
    var endTime: String?
    var priority: Priority?
    var status: TaskStatus?
    
    enum CodingKeys: String, CodingKey {
        case title, description, date, priority, status
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

// MARK: - User

struct User: Codable {
    let id: String
    let email: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

