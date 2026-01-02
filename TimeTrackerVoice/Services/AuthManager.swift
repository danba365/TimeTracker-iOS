import Foundation
import Combine
import GoogleSignIn

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var accessToken: String?
    private var refreshToken: String?
    
    private init() {
        loadStoredSession()
        configureGoogleSignIn()
    }
    
    // MARK: - Google Sign-In Configuration
    
    private func configureGoogleSignIn() {
        let config = GIDConfiguration(clientID: Config.googleClientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    // MARK: - Session Management
    
    private func loadStoredSession() {
        if let token = UserDefaults.standard.string(forKey: "access_token"),
           let userId = UserDefaults.standard.string(forKey: "user_id"),
           let email = UserDefaults.standard.string(forKey: "user_email") {
            self.accessToken = token
            self.currentUser = User(id: userId, email: email, createdAt: nil)
            self.isAuthenticated = true
        }
    }
    
    private func saveSession(accessToken: String, refreshToken: String?, user: User) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.currentUser = user
        self.isAuthenticated = true
        
        UserDefaults.standard.set(accessToken, forKey: "access_token")
        UserDefaults.standard.set(refreshToken, forKey: "refresh_token")
        UserDefaults.standard.set(user.id, forKey: "user_id")
        UserDefaults.standard.set(user.email, forKey: "user_email")
    }
    
    private func clearSession() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        isAuthenticated = false
        
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_email")
        
        // Sign out of Google
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Get the presenting view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.serverError("Could not get root view controller")
        }
        
        // Perform Google Sign-In
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.serverError("Failed to get ID token from Google")
        }
        
        // Exchange Google ID token with Supabase
        try await exchangeGoogleTokenWithSupabase(idToken: idToken)
        
        print("✅ Signed in with Google: \(result.user.profile?.email ?? "unknown")")
    }
    
    private func exchangeGoogleTokenWithSupabase(idToken: String) async throws {
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "provider": "google",
            "id_token": idToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(SupabaseError.self, from: data) {
                throw AuthError.serverError(errorResponse.message ?? errorResponse.error ?? "Google sign-in failed")
            }
            // Print the actual error for debugging
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ Supabase error: \(errorString)")
            }
            throw AuthError.serverError("Google sign-in failed")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user.id,
            email: authResponse.user.email ?? "unknown",
            createdAt: authResponse.user.createdAt
        )
        
        saveSession(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            user: user
        )
    }
    
    // Handle Google Sign-In URL callback
    func handleGoogleSignInURL(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(SupabaseError.self, from: data) {
                throw AuthError.serverError(errorResponse.message ?? "Authentication failed")
            }
            throw AuthError.serverError("Authentication failed")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user.id,
            email: authResponse.user.email ?? email,
            createdAt: authResponse.user.createdAt
        )
        
        saveSession(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            user: user
        )
        
        print("✅ Signed in as: \(email)")
    }
    
    func signOut() {
        clearSession()
        print("✅ Signed out")
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken ?? UserDefaults.standard.string(forKey: "refresh_token") else {
            print("❌ No refresh token available")
            return false
        }
        
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ Token refresh failed")
                return false
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            self.accessToken = authResponse.accessToken
            self.refreshToken = authResponse.refreshToken
            
            UserDefaults.standard.set(authResponse.accessToken, forKey: "access_token")
            if let newRefresh = authResponse.refreshToken {
                UserDefaults.standard.set(newRefresh, forKey: "refresh_token")
            }
            
            print("✅ Token refreshed successfully")
            return true
        } catch {
            print("❌ Token refresh error: \(error)")
            return false
        }
    }
}

// MARK: - Response Types

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

struct SupabaseError: Codable {
    let message: String?
    let error: String?
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case message, error
        case errorDescription = "error_description"
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}
