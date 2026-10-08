import Foundation
import Combine

/// A vacation / day-off range (mirrors the web app's `vacations` table).
struct VacationItem: Codable, Identifiable {
    let id: String
    let label: String?
    let start_date: String  // YYYY-MM-DD
    let end_date: String    // YYYY-MM-DD (inclusive)
}

/// Loads the user's vacations from Supabase and exposes "am I off today?".
@MainActor
class VacationManager: ObservableObject {
    static let shared = VacationManager()

    @Published var vacations: [VacationItem] = []

    private init() {}

    private static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// The vacation covering `date` (default today), if any.
    func vacation(on date: Date = Date()) -> VacationItem? {
        let day = Self.ymd(date)
        return vacations.first { $0.start_date <= day && day <= $0.end_date }
    }

    func fetchVacations() async {
        guard let token = AuthManager.shared.getAccessToken(),
              let userId = AuthManager.shared.currentUser?.id else {
            return
        }

        guard let url = URL(string: "\(Config.supabaseURL)/rest/v1/vacations?user_id=eq.\(userId)&order=start_date.asc") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            if http.statusCode == 401 {
                // Token expired: refresh once and retry.
                if await AuthManager.shared.refreshAccessToken() {
                    await fetchVacations()
                }
                return
            }
            if http.statusCode == 200 {
                vacations = (try? JSONDecoder().decode([VacationItem].self, from: data)) ?? []
            } else {
                print("❌ Vacations API status \(http.statusCode)")
            }
        } catch {
            print("❌ Vacation fetch error: \(error)")
        }
    }
}
