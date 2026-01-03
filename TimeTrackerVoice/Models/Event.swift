import Foundation

/// Event type enumeration
enum EventType: String, Codable, CaseIterable {
    case birthday
    case anniversary
    case custom
    
    var icon: String {
        switch self {
        case .birthday: return "🎂"
        case .anniversary: return "💍"
        case .custom: return "🎉"
        }
    }
    
    var displayName: String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        switch self {
        case .birthday:
            return isHebrew ? "יום הולדת" : "Birthday"
        case .anniversary:
            return isHebrew ? "יום נישואין" : "Anniversary"
        case .custom:
            return isHebrew ? "אירוע מותאם" : "Custom"
        }
    }
}

/// Event model matching Supabase events table
struct Event: Identifiable, Codable {
    let id: String
    var name: String
    var eventType: EventType
    var icon: String?
    var date: String  // Format: DD-MM (e.g., "15-03" for March 15)
    var year: Int?    // Original year of event (for calculating years since)
    var notes: String?
    var userId: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, date, year, notes
        case eventType = "event_type"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Get the display icon (custom or default based on type)
    var displayIcon: String {
        icon ?? eventType.icon
    }
    
    /// Check if this event occurs on a given date (matches day and month)
    func occursOn(date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        
        // Parse DD-MM format
        let components = self.date.split(separator: "-")
        guard components.count == 2,
              let eventDay = Int(components[0]),
              let eventMonth = Int(components[1]) else {
            return false
        }
        
        return eventDay == day && eventMonth == month
    }
    
    /// Calculate years since the original event (for anniversaries)
    var yearsSince: Int? {
        guard let originalYear = year else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - originalYear
    }
    
    /// Get formatted display for the event
    var displayText: String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        if let years = yearsSince, years > 0 {
            return isHebrew ? "\(name) (\(years) שנים)" : "\(name) (\(years) years)"
        }
        return name
    }
}

// MARK: - Create/Update Inputs

struct CreateEventInput: Codable {
    var name: String
    var eventType: EventType
    var icon: String?
    var date: String  // Format: DD-MM
    var year: Int?
    var notes: String?
    var userId: String?
    
    enum CodingKeys: String, CodingKey {
        case name, icon, date, year, notes
        case eventType = "event_type"
        case userId = "user_id"
    }
}

struct UpdateEventInput: Codable {
    var name: String?
    var eventType: EventType?
    var icon: String?
    var date: String?
    var year: Int?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case name, icon, date, year, notes
        case eventType = "event_type"
    }
}

