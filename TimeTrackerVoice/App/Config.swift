import Foundation

enum Config {
    // Supabase Configuration (same as web app)
    static let supabaseURL = "https://bifohzgibivvoozjptsa.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZm9oemdpYml2dm9vempwdHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4MTU1MzAsImV4cCI6MjA3NjM5MTUzMH0.fPt4PoQ2p-0dKeLWYVn7jDEbKvtzzZjVW714zYZM6KA"
    
    // Google Sign-In Configuration
    // Get this from Google Cloud Console -> APIs & Services -> Credentials -> OAuth 2.0 Client IDs
    // Create an iOS client ID with bundle ID: com.timetracker.voice
    static var googleClientID: String {
        // Check Info.plist first, then fall back to stored value
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientID.isEmpty && !clientID.contains("GOOGLE_CLIENT_ID") {
            return clientID
        }
        return UserDefaults.standard.string(forKey: "google_client_id") ?? ""
    }
    
    static func setGoogleClientID(_ clientID: String) {
        UserDefaults.standard.set(clientID, forKey: "google_client_id")
    }
    
    // OpenAI Configuration
    // TODO: Add your OpenAI API key here or load from secure storage
    static var openAIAPIKey: String {
        // In production, use Keychain or secure storage
        UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    static func setOpenAIAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }
    
    // OpenAI Realtime API
    static let openAIRealtimeURL = "wss://api.openai.com/v1/realtime"
    static let openAIRealtimeModel = "gpt-4o-realtime-preview-2024-12-17"
}

