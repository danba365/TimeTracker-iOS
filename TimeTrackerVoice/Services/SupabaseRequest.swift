import Foundation

/// Authorized request to Supabase (REST or Storage) with the user's JWT.
/// On 401 it refreshes the session once and retries.
enum SupabaseRequest {
    @MainActor
    static func send(
        _ url: URL,
        method: String = "GET",
        json: Any? = nil,
        body: Data? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        func perform() async throws -> (Data, HTTPURLResponse) {
            guard let token = AuthManager.shared.getAccessToken() else {
                throw URLError(.userAuthenticationRequired)
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            for (k, v) in extraHeaders { request.setValue(v, forHTTPHeaderField: k) }
            if let json {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: json)
            } else if let body {
                request.httpBody = body
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (data, http)
        }

        let first = try await perform()
        if first.1.statusCode == 401, await AuthManager.shared.refreshAccessToken() {
            return try await perform()
        }
        return first
    }
}
