import Foundation

/// Google Calendar events (read-only) via our Netlify functions.
/// Caches the last response so the calendar isn't empty offline.
@MainActor
final class CalendarEventManager: ObservableObject {
    static let shared = CalendarEventManager()

    @Published var events: [CalendarEvent] = []
    @Published var isConnected = false
    @Published var needsReconnect = false

    private let cacheKey = "cached_google_calendar"

    private init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CalendarEventsResponse.self, from: data) {
            apply(cached)
        }
    }

    func events(on date: Date) -> [CalendarEvent] {
        let day = TasksView.isoDay.string(from: date)
        return events.filter { $0.date == day }
    }

    /// Fetch events for [from, to] (inclusive). Keeps cached data on failure.
    func fetch(from: Date, to: Date) async {
        var components = URLComponents(string: Config.calendarEventsURL)
        components?.queryItems = [
            URLQueryItem(name: "from", value: TasksView.isoDay.string(from: from)),
            URLQueryItem(name: "to", value: TasksView.isoDay.string(from: to)),
            URLQueryItem(name: "tz", value: TimeZone.current.identifier),
        ]
        guard let url = components?.url, var request = authorizedRequest(url) else { return }
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
            apply(decoded)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("⚠️ Google Calendar fetch failed: \(error)")
        }
    }

    /// Send Google Sign-In's one-time serverAuthCode to the backend.
    /// Returns true when the calendar is connected.
    @discardableResult
    func connect(serverAuthCode: String) async -> Bool {
        guard let url = URL(string: Config.calendarConnectURL), var request = authorizedRequest(url) else { return false }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["serverAuthCode": serverAuthCode])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if ok {
                isConnected = true
                needsReconnect = false
            }
            return ok
        } catch {
            print("⚠️ Google Calendar connect failed: \(error)")
            return false
        }
    }

    func disconnect() async {
        guard let url = URL(string: Config.calendarConnectURL), var request = authorizedRequest(url) else { return }
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
        apply(CalendarEventsResponse(connected: false, reconnect: nil, events: []))
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func apply(_ response: CalendarEventsResponse) {
        events = response.events
        isConnected = response.connected
        needsReconnect = response.reconnect ?? false
    }

    private func authorizedRequest(_ url: URL) -> URLRequest? {
        guard let token = AuthManager.shared.getAccessToken() else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
