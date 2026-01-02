import Foundation
import SwiftUI

/// Centralized localization strings for the app
/// Supports Hebrew and English with persistent language selection
final class L10n: ObservableObject {
    
    // MARK: - Singleton
    static let shared = L10n()
    
    // MARK: - Language Enum
    enum Language: String, CaseIterable {
        case hebrew = "he"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .hebrew: return "עברית"
            case .english: return "English"
            }
        }
        
        var isRTL: Bool {
            self == .hebrew
        }
    }
    
    // MARK: - Current Language (persisted)
    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let language = Language(rawValue: saved) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .hebrew // Default to Hebrew
        }
    }
    
    // MARK: - Helper
    private var isHebrew: Bool { currentLanguage == .hebrew }
    
    // MARK: - Tab Bar
    var tabTasks: String { isHebrew ? "משימות" : "Tasks" }
    var tabChat: String { isHebrew ? "צ'אט" : "Chat" }
    var tabVoice: String { isHebrew ? "קול" : "Voice" }
    
    // MARK: - Common
    var today: String { isHebrew ? "היום" : "Today" }
    var yesterday: String { isHebrew ? "אתמול" : "Yesterday" }
    var tomorrow: String { isHebrew ? "מחר" : "Tomorrow" }
    var offlineMode: String { isHebrew ? "מצב לא מקוון" : "Offline Mode" }
    var refreshing: String { isHebrew ? "מעדכן..." : "Refreshing..." }
    var updated: String { isHebrew ? "עודכן" : "Updated" }
    var signOut: String { isHebrew ? "התנתק" : "Sign Out" }
    var settings: String { isHebrew ? "הגדרות" : "Settings" }
    var setAPIKey: String { isHebrew ? "הגדר API Key" : "Set API Key" }
    var cancel: String { isHebrew ? "ביטול" : "Cancel" }
    var save: String { isHebrew ? "שמור" : "Save" }
    var done: String { isHebrew ? "סיום" : "Done" }
    var language: String { isHebrew ? "שפה" : "Language" }
    
    // MARK: - Tasks View
    var noTasksTitle: String { isHebrew ? "אין משימות ליום זה" : "No tasks for this day" }
    var noTasksSubtitle: String { isHebrew ? "השתמש בקול או בצ'אט להוספת משימות" : "Use voice or chat to add tasks" }
    
    // MARK: - Chat View
    var aiAssistant: String { isHebrew ? "עוזר AI" : "AI Assistant" }
    var askMeAboutTasks: String { isHebrew ? "שאל אותי על המשימות שלך" : "Ask me about your tasks" }
    var clearChat: String { isHebrew ? "נקה צ'אט" : "Clear Chat" }
    var howCanIHelp: String { isHebrew ? "איך אפשר לעזור?" : "How can I help?" }
    var typeMessagePlaceholder: String { isHebrew ? "הקלד הודעה..." : "Type a message..." }
    var typeMessageHint: String { isHebrew ? "הקלד הודעה למטה כדי להתחיל" : "Type a message below to start" }
    
    // Chat suggestions
    var suggestionWhatToday: String { isHebrew ? "מה יש לי היום?" : "What do I have today?" }
    var suggestionAddTask: String { isHebrew ? "הוסף משימה" : "Add task" }
    var suggestionAddTaskFull: String { isHebrew ? "הוסף משימה חדשה מחר בבוקר" : "Add a new task tomorrow morning" }
    var examples: String { isHebrew ? "דוגמאות:" : "Examples:" }
    
    // MARK: - Voice View
    var voiceCoach: String { isHebrew ? "עוזר קולי" : "Voice Coach" }
    var aiWillRespond: String { isHebrew ? "הבינה המלאכותית תגיב כשתפסיק לדבר" : "AI will respond when you stop speaking" }
    var trySaying: String { isHebrew ? "נסה לומר:" : "Try saying:" }
    var speakNaturally: String { isHebrew ? "דבר באופן טבעי" : "Speak naturally" }
    
    // Voice tips
    var tipWhatToday: String { isHebrew ? "\"מה יש לי היום?\"" : "\"What do I have today?\"" }
    var tipWhatYesterday: String { isHebrew ? "\"מה עשיתי אתמול?\"" : "\"What did I do yesterday?\"" }
    var tipAddGym: String { isHebrew ? "\"הוסף חדר כושר מחר ב-7 בבוקר\"" : "\"Add gym tomorrow at 7am\"" }
    var tipHowManyContacts: String { isHebrew ? "\"כמה אנשי קשר יש לי?\"" : "\"How many contacts do I have?\"" }
    var tipAddMom: String { isHebrew ? "\"הוסף את אמא לאנשי הקשר\"" : "\"Add mom to contacts\"" }
    
    // MARK: - Voice States
    var tapToStart: String { isHebrew ? "לחץ להתחיל" : "Tap to start" }
    var listening: String { isHebrew ? "מקשיב..." : "Listening..." }
    var thinking: String { isHebrew ? "חושב..." : "Thinking..." }
    var speaking: String { isHebrew ? "מדבר..." : "Speaking..." }
    var errorOccurred: String { isHebrew ? "אירעה שגיאה" : "Error occurred" }
    
    // MARK: - Settings View
    var settingsTitle: String { isHebrew ? "הגדרות" : "Settings" }
    var account: String { isHebrew ? "חשבון" : "Account" }
    var signedInAs: String { isHebrew ? "מחובר כ-" : "Signed in as" }
    var preferences: String { isHebrew ? "העדפות" : "Preferences" }
    var apiKey: String { isHebrew ? "מפתח API" : "API Key" }
    var apiKeySet: String { isHebrew ? "מוגדר" : "Set" }
    var apiKeyNotSet: String { isHebrew ? "לא מוגדר" : "Not set" }
    var dataManagement: String { isHebrew ? "ניהול נתונים" : "Data Management" }
    var clearCache: String { isHebrew ? "נקה מטמון" : "Clear Cache" }
    var clearCacheDescription: String { isHebrew ? "מחיקת נתונים מקומיים" : "Delete local data" }
    var cacheCleared: String { isHebrew ? "המטמון נוקה" : "Cache cleared" }
    var about: String { isHebrew ? "אודות" : "About" }
    var version: String { isHebrew ? "גרסה" : "Version" }
    var enterAPIKey: String { isHebrew ? "הזן מפתח OpenAI API" : "Enter OpenAI API Key" }
    var apiKeyPlaceholder: String { isHebrew ? "sk-..." : "sk-..." }
    
    // MARK: - Auth View
    var welcomeTitle: String { isHebrew ? "ברוכים הבאים" : "Welcome" }
    var continueWithGoogle: String { isHebrew ? "המשך עם Google" : "Continue with Google" }
}

// MARK: - Static Accessors (for convenience)
extension L10n {
    // Tab Bar
    static var tabTasks: String { shared.tabTasks }
    static var tabChat: String { shared.tabChat }
    static var tabVoice: String { shared.tabVoice }
    
    // Common
    static var today: String { shared.today }
    static var yesterday: String { shared.yesterday }
    static var tomorrow: String { shared.tomorrow }
    static var offlineMode: String { shared.offlineMode }
    static var refreshing: String { shared.refreshing }
    static var updated: String { shared.updated }
    static var signOut: String { shared.signOut }
    static var settings: String { shared.settings }
    static var setAPIKey: String { shared.setAPIKey }
    static var cancel: String { shared.cancel }
    static var save: String { shared.save }
    static var done: String { shared.done }
    static var language: String { shared.language }
    
    // Tasks View
    static var noTasksTitle: String { shared.noTasksTitle }
    static var noTasksSubtitle: String { shared.noTasksSubtitle }
    
    // Chat View
    static var aiAssistant: String { shared.aiAssistant }
    static var askMeAboutTasks: String { shared.askMeAboutTasks }
    static var clearChat: String { shared.clearChat }
    static var howCanIHelp: String { shared.howCanIHelp }
    static var typeMessagePlaceholder: String { shared.typeMessagePlaceholder }
    static var typeMessageHint: String { shared.typeMessageHint }
    static var suggestionWhatToday: String { shared.suggestionWhatToday }
    static var suggestionAddTask: String { shared.suggestionAddTask }
    static var suggestionAddTaskFull: String { shared.suggestionAddTaskFull }
    static var examples: String { shared.examples }
    
    // Voice View
    static var voiceCoach: String { shared.voiceCoach }
    static var aiWillRespond: String { shared.aiWillRespond }
    static var trySaying: String { shared.trySaying }
    static var speakNaturally: String { shared.speakNaturally }
    static var tipWhatToday: String { shared.tipWhatToday }
    static var tipWhatYesterday: String { shared.tipWhatYesterday }
    static var tipAddGym: String { shared.tipAddGym }
    static var tipHowManyContacts: String { shared.tipHowManyContacts }
    static var tipAddMom: String { shared.tipAddMom }
    
    // Voice States
    static var tapToStart: String { shared.tapToStart }
    static var listening: String { shared.listening }
    static var thinking: String { shared.thinking }
    static var speaking: String { shared.speaking }
    static var errorOccurred: String { shared.errorOccurred }
    
    // Settings
    static var settingsTitle: String { shared.settingsTitle }
    static var account: String { shared.account }
    static var signedInAs: String { shared.signedInAs }
    static var preferences: String { shared.preferences }
    static var apiKey: String { shared.apiKey }
    static var apiKeySet: String { shared.apiKeySet }
    static var apiKeyNotSet: String { shared.apiKeyNotSet }
    static var dataManagement: String { shared.dataManagement }
    static var clearCache: String { shared.clearCache }
    static var clearCacheDescription: String { shared.clearCacheDescription }
    static var cacheCleared: String { shared.cacheCleared }
    static var about: String { shared.about }
    static var version: String { shared.version }
    static var enterAPIKey: String { shared.enterAPIKey }
    static var apiKeyPlaceholder: String { shared.apiKeyPlaceholder }
    
    // Auth
    static var welcomeTitle: String { shared.welcomeTitle }
    static var continueWithGoogle: String { shared.continueWithGoogle }
}
