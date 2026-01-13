import Foundation
import Combine

@MainActor
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [TaskItem] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncDate: Date?
    @Published var hasAPIError = false  // For API errors (not network issues)
    
    /// True offline status from NetworkMonitor
    var isOffline: Bool {
        !NetworkMonitor.shared.isConnected
    }
    
    // Cache keys
    private let tasksKey = "cached_tasks"
    private let categoriesKey = "cached_categories"
    private let lastSyncKey = "last_sync_date"
    
    private init() {
        // Load cached data immediately on init
        loadCachedData()
    }
    
    // MARK: - Local Cache Management
    
    /// Load cached tasks and categories from UserDefaults
    private func loadCachedData() {
        // Load cached tasks
        if let tasksData = UserDefaults.standard.data(forKey: tasksKey) {
            do {
                let cachedTasks = try JSONDecoder().decode([TaskItem].self, from: tasksData)
                self.tasks = cachedTasks
                print("📦 Loaded \(cachedTasks.count) cached tasks")
            } catch {
                print("⚠️ Failed to decode cached tasks: \(error)")
            }
        }
        
        // Load cached categories
        if let categoriesData = UserDefaults.standard.data(forKey: categoriesKey) {
            do {
                let cachedCategories = try JSONDecoder().decode([Category].self, from: categoriesData)
                self.categories = cachedCategories
                print("📦 Loaded \(cachedCategories.count) cached categories")
            } catch {
                print("⚠️ Failed to decode cached categories: \(error)")
            }
        }
        
        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = lastSync
            print("📦 Last sync: \(lastSync)")
        }
    }
    
    /// Save tasks to local cache
    private func saveTasksToCache() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            self.lastSyncDate = Date()
            print("💾 Saved \(tasks.count) tasks to cache")
        } catch {
            print("⚠️ Failed to save tasks to cache: \(error)")
        }
    }
    
    /// Save categories to local cache
    private func saveCategoriesToCache() {
        do {
            let data = try JSONEncoder().encode(categories)
            UserDefaults.standard.set(data, forKey: categoriesKey)
            print("💾 Saved \(categories.count) categories to cache")
        } catch {
            print("⚠️ Failed to save categories to cache: \(error)")
        }
    }
    
    /// Clear all cached data
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        tasks = []
        categories = []
        lastSyncDate = nil
        print("🗑️ Cache cleared")
    }
    
    // MARK: - Fetch Tasks
    
    func fetchTasks() async {
        guard let token = AuthManager.shared.getAccessToken() else {
            print("⚠️ No access token - using cached data only")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Fetch tasks for past 30 days to next 60 days (wider range for voice queries)
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 60, to: today)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        do {
            // Get user_id for filtering - only fetch tasks belonging to this user
            guard let userId = AuthManager.shared.currentUser?.id else {
                print("⚠️ No user_id available - cannot fetch tasks")
                return
            }
            
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/tasks?user_id=eq.\(userId)&date=gte.\(startStr)&date=lte.\(endStr)&order=date.asc,start_time.asc")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 10 // 10 second timeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Tasks API response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    print("⚠️ Token expired - attempting refresh...")
                    
                    // Try to refresh the token
                    let refreshed = await AuthManager.shared.refreshAccessToken()
                    
                    if refreshed {
                        // Retry the fetch with new token
                        print("🔄 Retrying fetch with new token...")
                        await fetchTasks()
                        return
                    } else {
                        print("❌ Token refresh failed - please log in again")
                        self.error = "Session expired. Please log in again."
                        hasAPIError = true
                        return
                    }
                }
                
                if httpResponse.statusCode != 200 {
                    // Try to parse error message
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = errorJson["message"] as? String {
                        print("❌ API Error: \(message)")
                        self.error = message
                    } else {
                        print("❌ HTTP Error: \(httpResponse.statusCode)")
                        self.error = "Server error: \(httpResponse.statusCode)"
                    }
                    hasAPIError = true
                    return
                }
            }
            
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
            
            // 🔍 DEBUG: Log task details to find duplicates
            print("🔍 ===== DEBUG: TASK DATA =====")
            let workTasks = tasks.filter { $0.title.lowercased().contains("work") }
            print("🔍 Found \(workTasks.count) 'Work' tasks:")
            for task in workTasks {
                print("   📋 Title: \(task.title)")
                print("      Date: \(task.date)")
                print("      ID: \(task.id)")
                print("      isRecurring: \(task.isRecurring)")
                print("      parentTaskId: \(task.parentTaskId ?? "nil")")
                print("      status: \(task.status)")
                print("   ---")
            }
            print("🔍 ===== END DEBUG =====")
            
            // ✅ Save to cache after successful fetch
            saveTasksToCache()
            hasAPIError = false
            
            print("✅ Fetched \(tasks.count) tasks from server")
        } catch {
            self.error = error.localizedDescription
            hasAPIError = true
            print("❌ Error fetching tasks: \(error)")
            
            // Debug: Print raw response to see what we got
            if let dataStr = String(data: Data(), encoding: .utf8) {
                print("📄 Raw response: \(dataStr)")
            }
            
            print("📦 Using \(tasks.count) cached tasks instead")
            // Tasks remain from cache - user can still see their data offline
        }
    }
    
    func fetchCategories() async {
        guard let token = AuthManager.shared.getAccessToken() else {
            print("⚠️ No access token - using cached categories only")
            return
        }
        
        do {
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/categories?order=name.asc")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            categories = try JSONDecoder().decode([Category].self, from: data)
            
            // ✅ Save to cache
            saveCategoriesToCache()
            
            print("✅ Fetched \(categories.count) categories from server")
        } catch {
            print("❌ Error fetching categories: \(error)")
            print("📦 Using \(categories.count) cached categories instead")
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
        
        // ✅ Save to cache after create
        saveTasksToCache()
        
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
        
        // ✅ Save to cache after update
        saveTasksToCache()
        
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
        
        // ✅ Save to cache after delete
        saveTasksToCache()
        
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
    
    func getPastTasks(days: Int = 7) -> [TaskItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: today)!
        let todayStr = formatter.string(from: today)
        let startStr = formatter.string(from: startDate)
        
        return tasks.filter { $0.date >= startStr && $0.date < todayStr }
    }
    
    func getTasksInRange(startDate: String, endDate: String) -> [TaskItem] {
        return tasks.filter { $0.date >= startDate && $0.date <= endDate }
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
