import Foundation

// MARK: - Person/Contact Models

enum RelationshipType: String, Codable, CaseIterable {
    case family
    case friend
    case colleague
    case other
}

struct Person: Identifiable, Codable {
    let id: String
    var firstName: String
    var lastName: String?
    var nickname: String?
    var relationshipType: RelationshipType
    var relationshipDetail: String?
    var phone: String?
    var email: String?
    var birthday: String?  // YYYY-MM-DD
    var anniversary: String?
    var notes: String?
    var avatarUrl: String?
    var createdAt: String
    var updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, nickname, phone, email, birthday, anniversary, notes
        case firstName = "first_name"
        case lastName = "last_name"
        case relationshipType = "relationship_type"
        case relationshipDetail = "relationship_detail"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Helper to get full name
    var fullName: String {
        if let last = lastName {
            return "\(firstName) \(last)"
        }
        return firstName
    }
    
    // Helper to get display name (nickname or full name)
    var displayName: String {
        nickname ?? fullName
    }
    
    // Helper to calculate age from birthday
    var age: Int? {
        guard let birthday = birthday else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: birthday) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }
    
    // Helper to get days until next birthday
    var daysUntilBirthday: Int? {
        guard let birthday = birthday else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: birthday) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Get this year's birthday
        var components = calendar.dateComponents([.month, .day], from: birthDate)
        components.year = calendar.component(.year, from: now)
        
        guard var nextBirthday = calendar.date(from: components) else { return nil }
        
        // If birthday has passed this year, use next year
        if nextBirthday < today {
            components.year = calendar.component(.year, from: now) + 1
            nextBirthday = calendar.date(from: components) ?? nextBirthday
        }
        
        let days = calendar.dateComponents([.day], from: today, to: nextBirthday)
        return days.day
    }
}

// MARK: - Create/Update Inputs

struct CreatePersonInput: Codable {
    var firstName: String
    var lastName: String?
    var nickname: String?
    var relationshipType: RelationshipType
    var relationshipDetail: String?
    var phone: String?
    var email: String?
    var birthday: String?
    var anniversary: String?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case nickname, phone, email, birthday, anniversary, notes
        case firstName = "first_name"
        case lastName = "last_name"
        case relationshipType = "relationship_type"
        case relationshipDetail = "relationship_detail"
    }
}

struct UpdatePersonInput: Codable {
    var firstName: String?
    var lastName: String?
    var nickname: String?
    var relationshipType: RelationshipType?
    var relationshipDetail: String?
    var phone: String?
    var email: String?
    var birthday: String?
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case nickname, phone, email, birthday, notes
        case firstName = "first_name"
        case lastName = "last_name"
        case relationshipType = "relationship_type"
        case relationshipDetail = "relationship_detail"
    }
}

