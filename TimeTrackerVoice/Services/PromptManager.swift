import Foundation

/// PromptManager - Fetches and caches AI prompts from Supabase
///
/// This service ensures both web and iOS apps use the same prompts.
/// Prompts are cached locally for 24 hours to minimize API calls.
final class PromptManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PromptManager()
    
    // MARK: - Properties
    @Published private(set) var isLoaded = false
    private var prompts: [String: AIPrompt] = [:]
    
    // Cache keys
    private let cacheKey = "ai_prompts_cache"
    private let cacheTimestampKey = "ai_prompts_timestamp"
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Models
    
    struct AIPrompt: Codable {
        let id: String
        let key: String
        let contentEn: String
        let contentHe: String
        let description: String?
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, key, description
            case contentEn = "content_en"
            case contentHe = "content_he"
            case updatedAt = "updated_at"
        }
    }
    
    private struct CachedPrompts: Codable {
        let prompts: [AIPrompt]
        let fetchedAt: Date
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFromCache()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the manager - loads from cache or fetches from Supabase
    func initialize() async {
        if isLoaded && !prompts.isEmpty {
            // Already loaded, check if refresh needed in background
            if shouldRefreshCache() {
                Task { await refreshInBackground() }
            }
            return
        }
        
        // Try cache first
        if loadFromCache() && !shouldRefreshCache() {
            print("📋 Using cached prompts")
            await MainActor.run { isLoaded = true }
            return
        }
        
        // Fetch from Supabase
        await fetchFromSupabase()
    }
    
    /// Get a prompt by key and language
    func getPrompt(key: String, language: L10n.Language) -> String {
        guard let prompt = prompts[key] else {
            print("⚠️ Prompt not found: \(key)")
            return ""
        }
        return language == .hebrew ? prompt.contentHe : prompt.contentEn
    }
    
    /// Get a prompt with variable substitution
    /// Variables should be in {variable} format
    func getPromptWithVars(key: String, language: L10n.Language, vars: [String: String]) -> String {
        var content = getPrompt(key: key, language: language)
        
        for (varName, value) in vars {
            content = content.replacingOccurrences(of: "{\(varName)}", with: value)
        }
        
        return content
    }
    
    /// Force refresh prompts from Supabase
    func refresh() async {
        await fetchFromSupabase()
    }
    
    // MARK: - Private Methods
    
    private func fetchFromSupabase() async {
        print("📡 Fetching prompts from Supabase...")
        
        guard let accessToken = await AuthManager.shared.getAccessToken() else {
            print("❌ No access token for fetching prompts")
            useDefaultPrompts()
            await MainActor.run { isLoaded = true }
            return
        }
        
        let urlString = "\(Config.supabaseURL)/rest/v1/ai_prompts?select=*&order=key"
        guard let url = URL(string: urlString) else {
            useDefaultPrompts()
            await MainActor.run { isLoaded = true }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Failed to fetch prompts: bad response")
                useDefaultPrompts()
                await MainActor.run { isLoaded = true }
                return
            }
            
            let fetchedPrompts = try JSONDecoder().decode([AIPrompt].self, from: data)
            
            if fetchedPrompts.isEmpty {
                print("⚠️ No prompts found in database")
                useDefaultPrompts()
            } else {
                setPrompts(fetchedPrompts)
                saveToCache(fetchedPrompts)
                print("✅ Fetched \(fetchedPrompts.count) prompts from Supabase")
            }
            
            await MainActor.run { isLoaded = true }
            
        } catch {
            print("❌ Error fetching prompts: \(error)")
            useDefaultPrompts()
            await MainActor.run { isLoaded = true }
        }
    }
    
    private func refreshInBackground() async {
        print("🔄 Refreshing prompts in background...")
        await fetchFromSupabase()
    }
    
    private func setPrompts(_ promptList: [AIPrompt]) {
        prompts.removeAll()
        for prompt in promptList {
            prompts[prompt.key] = prompt
        }
    }
    
    @discardableResult
    private func loadFromCache() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return false
        }
        
        do {
            let cached = try JSONDecoder().decode(CachedPrompts.self, from: data)
            setPrompts(cached.prompts)
            print("📦 Loaded \(cached.prompts.count) cached prompts")
            return true
        } catch {
            print("❌ Failed to decode cached prompts: \(error)")
            return false
        }
    }
    
    private func saveToCache(_ promptList: [AIPrompt]) {
        let cached = CachedPrompts(prompts: promptList, fetchedAt: Date())
        
        do {
            let data = try JSONEncoder().encode(cached)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
            print("💾 Saved \(promptList.count) prompts to cache")
        } catch {
            print("❌ Failed to cache prompts: \(error)")
        }
    }
    
    private func shouldRefreshCache() -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > cacheDuration
    }
    
    private func useDefaultPrompts() {
        print("⚠️ Using default prompts")
        
        let defaults: [AIPrompt] = [
            AIPrompt(
                id: "default-1",
                key: "system_instructions",
                contentEn: """
                You are a friendly and helpful productivity coach. Help the user manage their tasks and contacts. Be concise and friendly.

                You have access to task management and contacts tools:
                - get_tasks: Get tasks for a date or date range
                - create_task: Create a new task
                - update_task: Update a task
                - delete_task: Delete a task
                - get_contacts: Get list of contacts
                - create_contact: Create a new contact

                IMPORTANT: When user asks about tasks from a specific date, use get_tasks with appropriate dates!
                """,
                contentHe: """
                אתה מאמן פרודוקטיביות ידידותי ומועיל. עזור למשתמש לנהל את המשימות ואנשי הקשר שלו. היה תמציתי וידידותי.

                יש לך גישה לכלים לניהול משימות ואנשי קשר:
                - get_tasks: קבל משימות לתאריך או טווח
                - create_task: צור משימה חדשה
                - update_task: עדכן משימה
                - delete_task: מחק משימה
                - get_contacts: קבל רשימת אנשי קשר
                - create_contact: צור איש קשר חדש

                חשוב: כאשר המשתמש שואל על משימות מתאריך ספציפי, השתמש ב-get_tasks עם תאריכים מתאימים!
                """,
                description: "Default system instructions",
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            AIPrompt(
                id: "default-2",
                key: "context_injection",
                contentEn: "[YOUR TASK CONTEXT]\n\n{context}\n\nUse this information when I ask about my tasks.",
                contentHe: "[הקשר המשימות שלך]\n\n{context}\n\nהשתמש במידע זה כשאני שואל על המשימות שלי.",
                description: "Context injection template",
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            AIPrompt(
                id: "default-3",
                key: "context_acknowledgment",
                contentEn: "Briefly acknowledge you received the task info.",
                contentHe: "אשר בקצרה שקיבלת את המידע על המשימות.",
                description: "Context acknowledgment prompt",
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            AIPrompt(
                id: "default-4",
                key: "date_context",
                contentEn: "Today is: {date} ({day_name})",
                contentHe: "היום הוא: {date} ({day_name})",
                description: "Date context template",
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ),
            AIPrompt(
                id: "default-5",
                key: "voice_behavior",
                contentEn: "Keep responses concise - this is voice, not text.",
                contentHe: "שמור על תגובות קצרות - זו שיחה קולית.",
                description: "Voice behavior reminder",
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        ]
        
        setPrompts(defaults)
    }
}

