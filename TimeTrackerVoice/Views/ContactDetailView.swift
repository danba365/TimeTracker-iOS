import SwiftUI

/// Full contact detail view showing all contact information
struct ContactDetailView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    
    private let isHebrew = L10n.shared.currentLanguage == .hebrew
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f0f23")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar & Name Header
                    headerSection
                    
                    // Contact Actions (Call, Email)
                    if person.mobile != nil || person.phone != nil || person.email != nil {
                        contactActionsSection
                    }
                    
                    // Details Sections
                    detailsSection
                    
                    // Notes Section
                    if let notes = person.notes, !notes.isEmpty {
                        notesSection(notes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Text(initials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(avatarColor)
            }
            
            // Name
            VStack(spacing: 4) {
                Text(person.fullName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                if let nickname = person.nickname, !nickname.isEmpty {
                    Text("\"\(nickname)\"")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                
                // Relationship badge
                HStack(spacing: 6) {
                    Image(systemName: relationshipIcon)
                        .font(.system(size: 12))
                    Text(person.relationshipDetail ?? relationshipLabel)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(avatarColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(avatarColor.opacity(0.15))
                .cornerRadius(16)
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Contact Actions
    
    private var contactActionsSection: some View {
        HStack(spacing: 20) {
            // Call - prefer mobile, fallback to phone
            if let callNumber = person.mobile ?? person.phone, !callNumber.isEmpty {
                ContactActionButton(
                    icon: "phone.fill",
                    label: isHebrew ? "התקשר" : "Call",
                    color: Color(hex: "10b981")
                ) {
                    callPhone(callNumber)
                }
                
                ContactActionButton(
                    icon: "message.fill",
                    label: isHebrew ? "הודעה" : "Message",
                    color: Color(hex: "60a5fa")
                ) {
                    sendMessage(callNumber)
                }
            }
            
            if let email = person.email, !email.isEmpty {
                ContactActionButton(
                    icon: "envelope.fill",
                    label: isHebrew ? "אימייל" : "Email",
                    color: Color(hex: "f472b6")
                ) {
                    sendEmail(email)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Mobile - always show
            ContactDetailRow(
                icon: "iphone",
                label: isHebrew ? "נייד" : "Mobile",
                value: person.mobile ?? (isHebrew ? "לא הוזן" : "Not set"),
                iconColor: Color(hex: "10b981")
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Email - always show
            ContactDetailRow(
                icon: "envelope.fill",
                label: isHebrew ? "אימייל" : "Email",
                value: person.email ?? (isHebrew ? "לא הוזן" : "Not set"),
                iconColor: Color(hex: "60a5fa")
            )
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Phone (optional)
            if let phone = person.phone, !phone.isEmpty {
                ContactDetailRow(
                    icon: "phone.fill",
                    label: isHebrew ? "טלפון" : "Phone",
                    value: phone,
                    iconColor: Color(hex: "22d3ee")
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }
            
            // Birthday
            if let birthday = person.birthday {
                ContactDetailRow(
                    icon: "gift.fill",
                    label: isHebrew ? "יום הולדת" : "Birthday",
                    value: formatBirthday(birthday),
                    iconColor: Color(hex: "f472b6")
                )
                
                if person.anniversary != nil {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }
            
            // Anniversary
            if let anniversary = person.anniversary {
                ContactDetailRow(
                    icon: "heart.fill",
                    label: isHebrew ? "יום נישואין" : "Anniversary",
                    value: formatDate(anniversary),
                    iconColor: Color(hex: "ef4444")
                )
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Notes Section
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(Color(hex: "fbbf24"))
                Text(isHebrew ? "הערות" : "Notes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Text(notes)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: isHebrew ? .trailing : .leading)
                .multilineTextAlignment(isHebrew ? .trailing : .leading)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private var initials: String {
        let first = person.firstName.prefix(1).uppercased()
        let last = (person.lastName?.prefix(1).uppercased()) ?? ""
        return first + last
    }
    
    private var avatarColor: Color {
        switch person.relationshipType {
        case .family: return Color(hex: "f472b6")
        case .friend: return Color(hex: "60a5fa")
        case .colleague: return Color(hex: "fbbf24")
        case .other: return Color(hex: "a78bfa")
        }
    }
    
    private var relationshipIcon: String {
        switch person.relationshipType {
        case .family: return "house.fill"
        case .friend: return "person.2.fill"
        case .colleague: return "briefcase.fill"
        case .other: return "person.fill"
        }
    }
    
    private var relationshipLabel: String {
        switch person.relationshipType {
        case .family: return isHebrew ? "משפחה" : "Family"
        case .friend: return isHebrew ? "חבר" : "Friend"
        case .colleague: return isHebrew ? "עבודה" : "Work"
        case .other: return isHebrew ? "אחר" : "Other"
        }
    }
    
    private func formatBirthday(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        
        formatter.dateFormat = isHebrew ? "d בMMMM" : "MMMM d"
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        var result = formatter.string(from: date)
        
        if let age = person.age {
            result += isHebrew ? " (גיל \(age))" : " (Age \(age))"
        }
        
        return result
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        
        formatter.dateFormat = isHebrew ? "d בMMMM yyyy" : "MMMM d, yyyy"
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        return formatter.string(from: date)
    }
    
    private func callPhone(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendMessage(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "sms://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Contact Action Button

struct ContactActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
        }
    }
}

// MARK: - Contact Detail Row

struct ContactDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748b"))
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(person: Person(
            id: "1",
            firstName: "John",
            lastName: "Doe",
            nickname: "Johnny",
            relationshipType: .friend,
            relationshipDetail: "Best Friend",
            phone: "+1 555 123 4567",
            mobile: "+1 555 987 6543",
            email: "john@example.com",
            birthday: "1990-05-15",
            anniversary: nil,
            notes: "Met at college. Likes basketball.",
            avatarUrl: nil,
            createdAt: "2024-01-01",
            updatedAt: "2024-01-01"
        ))
    }
}
