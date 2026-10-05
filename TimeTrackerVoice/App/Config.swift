import Foundation

enum Config {
    // Supabase Configuration (same as web app)
    // NOTE: the anon key is public by design and safe to ship in the client;
    // data isolation is enforced by Row Level Security on the server.
    static let supabaseURL = "https://bifohzgibivvoozjptsa.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpZm9oemdpYml2dm9vempwdHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA4MTU1MzAsImV4cCI6MjA3NjM5MTUzMH0.fPt4PoQ2p-0dKeLWYVn7jDEbKvtzzZjVW714zYZM6KA"

    // Google Sign-In Configuration (iOS Client ID)
    static let googleClientID = "914000186889-djtm5ohohh7dndee6g38243ejhjpi599.apps.googleusercontent.com"

    // MARK: - Backend functions

    /// Base URL of the deployed Netlify site hosting the serverless functions.
    /// Production Netlify domain that hosts the serverless functions.
    /// When set (not the YOUR-SITE placeholder), the app fetches short-lived
    /// ephemeral tokens for the Realtime API instead of shipping a standing
    /// OpenAI key on the device.
    static let functionsBaseURL = "https://stirring-souffle-c6bc1a.netlify.app"

    /// True once functionsBaseURL has been pointed at a real site.
    static var usesEphemeralRealtimeToken: Bool {
        !functionsBaseURL.contains("YOUR-SITE")
    }

    /// Endpoint that mints an ephemeral OpenAI Realtime session token.
    static var realtimeSessionURL: String {
        "\(functionsBaseURL)/.netlify/functions/realtime-session"
    }

    // MARK: - OpenAI

    /// OpenAI API key. OPTIONAL now - only used as a legacy fallback when
    /// `usesEphemeralRealtimeToken` is false. Stored securely in the Keychain;
    /// any value previously saved in UserDefaults is migrated on first read.
    static var openAIAPIKey: String {
        if let key = KeychainHelper.shared.get(openAIKeyKeychainKey), !key.isEmpty {
            return key
        }
        // One-time migration from the old (insecure) UserDefaults location.
        if let legacy = UserDefaults.standard.string(forKey: openAIKeyKeychainKey), !legacy.isEmpty {
            KeychainHelper.shared.set(legacy, for: openAIKeyKeychainKey)
            UserDefaults.standard.removeObject(forKey: openAIKeyKeychainKey)
            return legacy
        }
        return ""
    }

    static func setOpenAIAPIKey(_ key: String) {
        KeychainHelper.shared.set(key, for: openAIKeyKeychainKey)
    }

    private static let openAIKeyKeychainKey = "openai_api_key"

    // OpenAI Realtime API
    static let openAIRealtimeURL = "wss://api.openai.com/v1/realtime"
    static let openAIRealtimeModel = "gpt-4o-realtime-preview-2024-12-17"
}
