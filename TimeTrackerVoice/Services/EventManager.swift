import Foundation
import Combine

/// Manages events (anniversaries, etc.) from Supabase
class EventManager: ObservableObject {
    static let shared = EventManager()
    
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var isOffline = false
    
    private let eventsKey = "cached_events"
    private let lastSyncKey = "events_last_sync"
    
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }
    
    private init() {
        loadCachedData()
    }
    
    // MARK: - Caching
    
    private func loadCachedData() {
        // Load events from cache
        if let eventsData = UserDefaults.standard.data(forKey: eventsKey),
           let cachedEvents = try? JSONDecoder().decode([Event].self, from: eventsData) {
            self.events = cachedEvents
            print("📦 Loaded \(cachedEvents.count) cached events")
        }
        
        if let lastSync = lastSyncDate {
            print("📦 Events last sync: \(lastSync)")
        }
    }
    
    private func saveEventsToCache() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
            UserDefaults.standard.set(Date(), forKey: lastSyncKey)
            print("💾 Saved \(events.count) events to cache")
        }
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: eventsKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        events = []
        print("🗑️ Events cache cleared")
    }
    
    // MARK: - Fetch Events
    
    @MainActor
    func fetchEvents() async {
        guard let token = await AuthManager.shared.getAccessToken() else {
            print("❌ Not authenticated to fetch events")
            isOffline = true
            return
        }
        
        isLoading = true
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/events?order=date")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Events API response status: \(httpResponse.statusCode)")
            }
            
            let fetchedEvents = try JSONDecoder().decode([Event].self, from: data)
            
            self.events = fetchedEvents
            self.isOffline = false
            saveEventsToCache()
            
            print("✅ Fetched \(fetchedEvents.count) events from server")
        } catch {
            print("❌ Error fetching events: \(error)")
            isOffline = true
            // Keep using cached data
        }
        
        isLoading = false
    }
    
    // MARK: - Create Event
    
    @MainActor
    func createEvent(_ input: CreateEventInput) async throws -> Event {
        guard let token = await AuthManager.shared.getAccessToken() else {
            throw EventError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/events")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw EventError.createFailed
        }
        
        let fetchedEvents = try JSONDecoder().decode([Event].self, from: data)
        guard let newEvent = fetchedEvents.first else {
            throw EventError.createFailed
        }
        
        self.events.append(newEvent)
        saveEventsToCache()
        
        print("✅ Created event: \(newEvent.name)")
        return newEvent
    }
    
    // MARK: - Update Event
    
    @MainActor
    func updateEvent(id: String, input: UpdateEventInput) async throws -> Event {
        guard let token = await AuthManager.shared.getAccessToken() else {
            throw EventError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/events?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        request.httpBody = try JSONEncoder().encode(input)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EventError.updateFailed
        }
        
        let fetchedEvents = try JSONDecoder().decode([Event].self, from: data)
        guard let updatedEvent = fetchedEvents.first else {
            throw EventError.updateFailed
        }
        
        if let index = events.firstIndex(where: { $0.id == id }) {
            events[index] = updatedEvent
        }
        saveEventsToCache()
        
        print("✅ Updated event: \(updatedEvent.name)")
        return updatedEvent
    }
    
    // MARK: - Delete Event
    
    @MainActor
    func deleteEvent(id: String) async throws {
        guard let token = await AuthManager.shared.getAccessToken() else {
            throw EventError.notAuthenticated
        }
        
        let url = URL(string: "\(Config.supabaseURL)/rest/v1/events?id=eq.\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            throw EventError.deleteFailed
        }
        
        events.removeAll { $0.id == id }
        saveEventsToCache()
        
        print("✅ Deleted event")
    }
    
    // MARK: - Helpers
    
    /// Get events that occur on a specific date (matches day and month)
    /// Deduplicates by name to avoid showing duplicate entries
    func getEventsForDate(_ date: Date) -> [Event] {
        let matchingEvents = events.filter { $0.occursOn(date: date) }
        
        // Deduplicate by name (keep the one with year info if available)
        var seenNames = Set<String>()
        var uniqueEvents: [Event] = []
        
        for event in matchingEvents {
            let key = event.name.lowercased()
            if !seenNames.contains(key) {
                seenNames.insert(key)
                uniqueEvents.append(event)
            } else {
                // If we already have this event, prefer the one with year info
                if let existingIndex = uniqueEvents.firstIndex(where: { $0.name.lowercased() == key }) {
                    if uniqueEvents[existingIndex].year == nil && event.year != nil {
                        uniqueEvents[existingIndex] = event
                    }
                }
            }
        }
        
        return uniqueEvents
    }
    
    /// Check if there's an event on a specific date
    func hasEventOnDate(_ date: Date) -> Bool {
        return events.contains { $0.occursOn(date: date) }
    }
}

// MARK: - Errors

enum EventError: Error, LocalizedError {
    case notAuthenticated
    case createFailed
    case updateFailed
    case deleteFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .createFailed:
            return "Failed to create event"
        case .updateFailed:
            return "Failed to update event"
        case .deleteFailed:
            return "Failed to delete event"
        }
    }
}

