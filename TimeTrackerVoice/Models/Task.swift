import Foundation

// MARK: - Task Models

enum Priority: String, Codable, CaseIterable {
    case low, medium, high
}

enum TaskStatus: String, Codable, CaseIterable {
    case todo
    case inProgress = "in_progress"
    case done
    case missed
}

enum TaskType: String, Codable {
    case task, reminder
}

struct TaskItem: Identifiable, Codable {
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
    var parentTaskId: String?  // For recurring task instances
    var createdAt: String
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, date, priority, status, tags
        case startTime = "start_time"
        case endTime = "end_time"
        case taskType = "task_type"
        case categoryId = "category_id"
        case isRecurring = "is_recurring"
        case parentTaskId = "parent_task_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Returns true if this task should be displayed on a given date
    /// Recurring parent tasks are only shown on their original date, not on instance dates
    var isDisplayableTask: Bool {
        // Non-recurring tasks are always displayable
        if !isRecurring {
            return true
        }
        // Recurring instances (have parent) are displayable
        if parentTaskId != nil {
            return true
        }
        // Recurring parent tasks - we'll filter these in the view
        // to only show on their original creation date
        return true
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
    var userId: String?  // Required for Supabase RLS
    
    enum CodingKeys: String, CodingKey {
        case title, description, date, priority, status, tags
        case startTime = "start_time"
        case endTime = "end_time"
        case taskType = "task_type"
        case categoryId = "category_id"
        case isRecurring = "is_recurring"
        case userId = "user_id"
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
