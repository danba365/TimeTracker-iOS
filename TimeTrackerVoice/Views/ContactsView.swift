import SwiftUI

/// Contacts view displaying all contacts organized by relationship type
struct ContactsView: View {
    @EnvironmentObject var peopleManager: PeopleManager
    @State private var searchText = ""
    @State private var selectedFilter: RelationshipType? = nil
    @State private var showingAddContact = false
    
    private var filteredPeople: [Person] {
        var people = peopleManager.people
        
        // Filter by relationship type
        if let filter = selectedFilter {
            people = people.filter { $0.relationshipType == filter }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            people = people.filter { person in
                person.firstName.lowercased().contains(searchLower) ||
                (person.lastName?.lowercased().contains(searchLower) ?? false) ||
                (person.nickname?.lowercased().contains(searchLower) ?? false) ||
                person.fullName.lowercased().contains(searchLower)
            }
        }
        
        // Sort alphabetically
        return people.sorted { $0.firstName < $1.firstName }
    }
    
    private var upcomingBirthdays: [Person] {
        peopleManager.getUpcomingBirthdays(days: 30)
    }
    
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
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Filter chips
                filterChipsView
                
                // Search bar
                searchBarView
                
                // Contacts list
                if peopleManager.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    contactsListView
                }
            }
        }
        .onAppear {
            Task {
                await peopleManager.fetchPeople()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.contacts)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(contactsCountText)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Spacer()
            
            // Add contact button (placeholder for future)
            Button(action: { showingAddContact = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    private var contactsCountText: String {
        let count = filteredPeople.count
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        return isHebrew ? "\(count) אנשי קשר" : "\(count) contacts"
    }
    
    // MARK: - Filter Chips
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "הכל" : "All",
                    isSelected: selectedFilter == nil
                ) {
                    selectedFilter = nil
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "משפחה" : "Family",
                    icon: "house.fill",
                    isSelected: selectedFilter == .family
                ) {
                    selectedFilter = selectedFilter == .family ? nil : .family
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "חברים" : "Friends",
                    icon: "person.2.fill",
                    isSelected: selectedFilter == .friend
                ) {
                    selectedFilter = selectedFilter == .friend ? nil : .friend
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "עבודה" : "Work",
                    icon: "briefcase.fill",
                    isSelected: selectedFilter == .colleague
                ) {
                    selectedFilter = selectedFilter == .colleague ? nil : .colleague
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "אחר" : "Other",
                    icon: "person.fill",
                    isSelected: selectedFilter == .other
                ) {
                    selectedFilter = selectedFilter == .other ? nil : .other
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "64748b"))
            
            TextField(
                L10n.shared.currentLanguage == .hebrew ? "חיפוש אנשי קשר..." : "Search contacts...",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "64748b"))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Contacts List
    
    private var contactsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Upcoming birthdays section
                if !upcomingBirthdays.isEmpty && selectedFilter == nil && searchText.isEmpty {
                    upcomingBirthdaysSection
                }
                
                // Contacts
                if filteredPeople.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredPeople, id: \.id) { person in
                        ContactRowView(person: person)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .refreshable {
            await peopleManager.fetchPeople()
        }
    }
    
    // MARK: - Upcoming Birthdays Section
    
    private var upcomingBirthdaysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎂")
                    .font(.system(size: 18))
                Text(L10n.shared.currentLanguage == .hebrew ? "ימי הולדת קרובים" : "Upcoming Birthdays")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            ForEach(upcomingBirthdays.prefix(3), id: \.id) { person in
                UpcomingBirthdayRow(person: person)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "475569"))
            
            Text(L10n.shared.currentLanguage == .hebrew ? "לא נמצאו אנשי קשר" : "No contacts found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "64748b"))
            
            if !searchText.isEmpty {
                Text(L10n.shared.currentLanguage == .hebrew ? "נסה לחפש משהו אחר" : "Try a different search")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "475569"))
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color(hex: "a78bfa") : Color.white.opacity(0.08))
            .foregroundColor(isSelected ? .white : Color(hex: "94a3b8"))
            .cornerRadius(20)
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(initials)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(avatarColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(person.fullName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    // Relationship
                    Text(person.relationshipDetail ?? relationshipLabel)
                        .font(.system(size: 12))
                        .foregroundColor(avatarColor)
                    
                    // Birthday indicator
                    if person.birthday != nil {
                        if let days = person.daysUntilBirthday {
                            if days == 0 {
                                Text("🎂 " + (L10n.shared.currentLanguage == .hebrew ? "היום!" : "Today!"))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "f472b6"))
                            } else if days <= 7 {
                                Text("🎂 " + (L10n.shared.currentLanguage == .hebrew ? "עוד \(days) ימים" : "in \(days) days"))
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "f472b6"))
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Quick actions
            HStack(spacing: 12) {
                if let phone = person.phone, !phone.isEmpty {
                    Button(action: { callPhone(phone) }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "10b981"))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var initials: String {
        let first = person.firstName.prefix(1).uppercased()
        let last = (person.lastName?.prefix(1).uppercased()) ?? ""
        return first + last
    }
    
    private var avatarColor: Color {
        switch person.relationshipType {
        case .family:
            return Color(hex: "f472b6") // Pink
        case .friend:
            return Color(hex: "60a5fa") // Blue
        case .colleague:
            return Color(hex: "fbbf24") // Yellow
        case .other:
            return Color(hex: "a78bfa") // Purple
        }
    }
    
    private var relationshipLabel: String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        switch person.relationshipType {
        case .family:
            return isHebrew ? "משפחה" : "Family"
        case .friend:
            return isHebrew ? "חבר" : "Friend"
        case .colleague:
            return isHebrew ? "עבודה" : "Work"
        case .other:
            return isHebrew ? "אחר" : "Other"
        }
    }
    
    private func callPhone(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Upcoming Birthday Row

struct UpcomingBirthdayRow: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 12) {
            Text("🎂")
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(person.fullName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if let days = person.daysUntilBirthday {
                    Text(daysText(days))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "f472b6"))
                }
            }
            
            Spacer()
            
            if let age = person.age {
                Text(L10n.shared.currentLanguage == .hebrew ? "ימלאו \(age + 1)" : "Turning \(age + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color(hex: "f472b6").opacity(0.1), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(10)
    }
    
    private func daysText(_ days: Int) -> String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        if days == 0 {
            return isHebrew ? "היום!" : "Today!"
        } else if days == 1 {
            return isHebrew ? "מחר" : "Tomorrow"
        } else {
            return isHebrew ? "עוד \(days) ימים" : "In \(days) days"
        }
    }
}

#Preview {
    ContactsView()
        .environmentObject(PeopleManager.shared)
}

