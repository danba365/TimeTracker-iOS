import Foundation

/// A Google Calendar event as returned by the google-calendar-events function.
/// Dates/times are already in the device's time zone.
struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let date: String        // YYYY-MM-DD
    let startTime: String?  // HH:mm
    let endTime: String?
    let allDay: Bool
    let location: String?
    let link: String?
}

struct CalendarEventsResponse: Codable {
    let connected: Bool
    let reconnect: Bool?
    let events: [CalendarEvent]
}
