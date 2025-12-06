import Foundation
import Combine

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
    }
    
    // MARK: - Authentication
    
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
    
    func signInWithMagicLink(email: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(Config.supabaseURL)/auth/v1/otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "create_user": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(SupabaseError.self, from: data) {
                throw AuthError.serverError(errorResponse.message ?? "Failed to send magic link")
            }
            throw AuthError.serverError("Failed to send magic link")
        }
        
        print("✅ Magic link sent to: \(email)")
    }
    
    func signOut() {
        clearSession()
        print("✅ Signed out")
    }
    
    func getAccessToken() -> String? {
        return accessToken
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

