import Foundation
import Combine

@MainActor
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [TaskItem] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Fetch Tasks
    
    func fetchTasks() async {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        // Fetch tasks for past week to next month
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 30, to: today)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        do {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/tasks?date=gte.\(startStr)&date=lte.\(endStr)&order=date.asc,start_time.asc")!
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
            print("✅ Fetched \(tasks.count) tasks")
        } catch {
            self.error = error.localizedDescription
            print("❌ Error fetching tasks: \(error)")
        }
    }
    
    func fetchCategories() async {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        
        do {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/categories?order=name.asc")!
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            categories = try JSONDecoder().decode([Category].self, from: data)
            print("✅ Fetched \(categories.count) categories")
        } catch {
            print("❌ Error fetching categories: \(error)")
        }
    }
    
    // MARK: - Task Operations
    
    func createTask(_ input: CreateTaskInput) async throws -> TaskItem {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw TaskError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw TaskError.createFailed
        }
        
        let fetchedTasks = try JSONDecoder().decode([TaskItem].self, from: data)
        guard let newTask = fetchedTasks.first else {
            throw TaskError.createFailed
        }
        
        self.tasks.append(newTask)
        self.tasks.sort { $0.date < $1.date }
        
        print("✅ Created task: \(newTask.title)")
        return newTask
    }
    
    func updateTask(id: String, input: UpdateTaskInput) async throws -> TaskItem {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw TaskError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/tasks?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw TaskError.updateFailed
        }
        
        let fetchedTasks = try JSONDecoder().decode([TaskItem].self, from: data)
        guard let updatedTask = fetchedTasks.first else {
            throw TaskError.updateFailed
        }
        
        if let index = self.tasks.firstIndex(where: { $0.id == id }) {
            self.tasks[index] = updatedTask
        }
        
        print("✅ Updated task: \(updatedTask.title)")
        return updatedTask
    }
    
    func deleteTask(id: String) async throws {
        guard let token = AuthManager.shared.getAccessToken() else {
            throw TaskError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/tasks?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw TaskError.deleteFailed
        }
        
        tasks.removeAll { $0.id == id }
        print("✅ Deleted task")
    }
    
    // MARK: - Helpers
    
    func getTodaysTasks() -> [TaskItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return tasks.filter { $0.date == today }
    }
    
    func getTasksByDate(_ date: String) -> [TaskItem] {
        return tasks.filter { $0.date == date }
    }
    
    func getUpcomingTasks(days: Int = 7) -> [TaskItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: today)!
        let todayStr = formatter.string(from: today)
        let endStr = formatter.string(from: endDate)
        
        return tasks.filter { $0.date >= todayStr && $0.date <= endStr }
    }
    
    func getCategoryById(_ id: String) -> Category? {
        return categories.first { $0.id == id }
    }
    
    func findTask(byTitle title: String, date: String? = nil) -> TaskItem? {
        let matching = tasks.filter { 
            $0.title.lowercased().contains(title.lowercased())
        }
        
        if let date = date {
            return matching.first { $0.date == date }
        }
        
        // Prioritize today's tasks
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        return matching.first { $0.date == today } ?? matching.first
    }
}

// MARK: - Errors

enum TaskError: LocalizedError {
    case notAuthenticated
    case createFailed
    case updateFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .createFailed:
            return "Failed to create task"
        case .updateFailed:
            return "Failed to update task"
        case .deleteFailed:
            return "Failed to delete task"
        }
    }
}
