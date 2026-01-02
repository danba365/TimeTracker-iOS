import Foundation

/// Centralized localization strings for the app
/// Currently Hebrew-only. To add English, add a language toggle and conditional returns.
struct L10n {
    
    // MARK: - Tab Bar
    static let tabTasks = "משימות"
    static let tabChat = "צ'אט"
    static let tabVoice = "קול"
    
    // MARK: - Common
    static let today = "היום"
    static let yesterday = "אתמול"
    static let tomorrow = "מחר"
    static let offlineMode = "מצב לא מקוון"
    static let refreshing = "מעדכן..."
    static let updated = "עודכן"
    static let signOut = "התנתק"
    static let settings = "הגדרות"
    static let setAPIKey = "הגדר API Key"
    static let cancel = "ביטול"
    static let save = "שמור"
    
    // MARK: - Tasks View
    static let noTasksTitle = "אין משימות ליום זה"
    static let noTasksSubtitle = "השתמש בקול או בצ'אט להוספת משימות"
    
    // MARK: - Chat View
    static let aiAssistant = "עוזר AI"
    static let askMeAboutTasks = "שאל אותי על המשימות שלך"
    static let clearChat = "נקה צ'אט"
    static let howCanIHelp = "איך אפשר לעזור?"
    static let typeMessagePlaceholder = "הקלד הודעה..."
    static let typeMessageHint = "הקלד הודעה למטה כדי להתחיל"
    
    // Chat suggestions
    static let suggestionWhatToday = "מה יש לי היום?"
    static let suggestionAddTask = "הוסף משימה"
    static let suggestionAddTaskFull = "הוסף משימה חדשה מחר בבוקר"
    
    // MARK: - Voice View
    static let voiceCoach = "עוזר קולי"
    static let aiWillRespond = "הבינה המלאכותית תגיב כשתפסיק לדבר"
    static let trySaying = "נסה לומר:"
    static let speakNaturally = "דבר באופן טבעי"
    
    // Voice tips
    static let tipWhatToday = "\"מה יש לי היום?\""
    static let tipWhatYesterday = "\"מה עשיתי אתמול?\""
    static let tipAddGym = "\"הוסף חדר כושר מחר ב-7 בבוקר\""
    static let tipHowManyContacts = "\"כמה אנשי קשר יש לי?\""
    static let tipAddMom = "\"הוסף את אמא לאנשי הקשר\""
    
    // MARK: - Voice States
    static let tapToStart = "לחץ להתחיל"
    static let listening = "מקשיב..."
    static let thinking = "חושב..."
    static let speaking = "מדבר..."
    static let errorOccurred = "אירעה שגיאה"
    
    // MARK: - Future: Language Toggle
    // When adding English support, uncomment and modify:
    /*
    enum Language: String {
        case hebrew = "he"
        case english = "en"
    }
    
    static var currentLanguage: Language = .hebrew
    
    static var tabTasks: String {
        currentLanguage == .hebrew ? "משימות" : "Tasks"
    }
    */
}

