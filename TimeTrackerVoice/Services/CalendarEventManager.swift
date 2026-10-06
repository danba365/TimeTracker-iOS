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

    /// Incremented by reset(); in-flight fetches from an older generation are dropped.
    private var generation = 0

    private init() {
        guard Config.isGoogleCalendarEnabled else { return }
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
        guard let url = components?.url else { return }
        let startGeneration = generation

        do {
            guard let (data, response) = try await send(url: url, method: "GET", body: nil) else { return }
            guard generation == startGeneration else { return }
            guard response.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
            let fromDay = TasksView.isoDay.string(from: from)
            let toDay = TasksView.isoDay.string(from: to)
            let merged: [CalendarEvent]
            if decoded.connected {
                // yyyy-MM-dd compares correctly as a string.
                let outside = events.filter { $0.date < fromDay || $0.date > toDay }
                merged = outside + decoded.events
            } else {
                merged = []
            }
            let result = CalendarEventsResponse(connected: decoded.connected, reconnect: decoded.reconnect, events: merged)
            apply(result)
            if let encoded = try? JSONEncoder().encode(result) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
        } catch {
            print("⚠️ Google Calendar fetch failed: \(error)")
        }
    }

    /// Send Google Sign-In's one-time serverAuthCode to the backend.
    /// Returns true when the calendar is connected.
    @discardableResult
    func connect(serverAuthCode: String) async -> Bool {
        guard let url = URL(string: Config.calendarConnectURL) else { return false }
        let body = try? JSONSerialization.data(withJSONObject: ["serverAuthCode": serverAuthCode])

        do {
            guard let (_, response) = try await send(url: url, method: "POST", body: body) else { return false }
            let ok = response.statusCode == 200
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
        reset()
    }

    /// Clear in-memory state and the on-disk cache (sign-out / user switch / disconnect).
    func reset() {
        generation += 1
        events = []
        isConnected = false
        needsReconnect = false
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    private func apply(_ response: CalendarEventsResponse) {
        events = response.events
        isConnected = response.connected
        needsReconnect = response.reconnect ?? false
    }

    /// Sends an authorized request; on HTTP 401 refreshes the token and retries once.
    /// Returns nil when there is no access token.
    private func send(url: URL, method: String, body: Data?) async throws -> (Data, HTTPURLResponse)? {
        func perform() async throws -> (Data, HTTPURLResponse)? {
            guard var request = authorizedRequest(url) else { return nil }
            request.httpMethod = method
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            return (data, http)
        }
        guard let first = try await perform() else { return nil }
        if first.1.statusCode == 401, await AuthManager.shared.refreshAccessToken() {
            return try await perform()
        }
        return first
    }

    private func authorizedRequest(_ url: URL) -> URLRequest? {
        guard let token = AuthManager.shared.getAccessToken() else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
