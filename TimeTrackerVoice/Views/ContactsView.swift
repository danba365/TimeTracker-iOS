import SwiftUI
import Contacts

/// Contacts view displaying all contacts organized by relationship type
struct ContactsView: View {
    @EnvironmentObject var peopleManager: PeopleManager
    @State private var searchText = ""
    @State private var selectedFilter: RelationshipType? = nil
    @State private var showingAddContact = false
    @State private var showingContactPicker = false
    @State private var pickedContacts: [CNContact] = []
    @State private var showingImportReview = false
    @State private var importingCount = 0
    @State private var importResult: (success: Int, duplicates: Int)? = nil
    @FocusState private var isSearchFocused: Bool
    
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
        NavigationStack {
            ZStack {
                // Background — Sorbet "people" lavender tint
                SorbetTheme.ViewTint.people.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        isSearchFocused = false
                    }
                
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
                            .progressViewStyle(CircularProgressViewStyle(tint: SorbetTheme.ViewTint.people.accent))
                        Spacer()
                    } else {
                        contactsListView
                    }
                }
            }
            .onTapGesture {
                isSearchFocused = false
            }
            .onAppear {
                Task {
                    await peopleManager.fetchPeople()
                }
            }
            .navigationBarHidden(true)
            .background(
                ContactPicker(isPresented: $showingContactPicker) { contacts in
                    pickedContacts = contacts
                    if !contacts.isEmpty {
                        showingImportReview = true
                    }
                }
            )
            .sheet(isPresented: $showingImportReview) {
                ContactImportReviewView(
                    contacts: pickedContacts,
                    onImport: { pairs in
                        showingImportReview = false
                        Task { await importContacts(pairs) }
                    },
                    onCancel: { showingImportReview = false }
                )
            }
            .overlay {
                if importingCount > 0 {
                    importingOverlay
                }
                if let result = importResult {
                    importResultOverlay(result)
                }
            }
        }
    }
    
    // MARK: - Import Logic
    
    private func importContacts(_ pairs: [(CNContact, RelationshipType)]) async {
        importingCount = pairs.count
        var success = 0
        var duplicates = 0
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            importingCount = 0
            return
        }
        
        for (contact, type) in pairs {
            let firstName = contact.givenName
            let lastName = contact.familyName.isEmpty ? nil : contact.familyName
            
            let alreadyExists = peopleManager.people.contains { existing in
                existing.firstName.lowercased() == firstName.lowercased() &&
                (existing.lastName?.lowercased() ?? "") == (lastName?.lowercased() ?? "")
            }
            
            if alreadyExists {
                duplicates += 1
                continue
            }
            
            let phone = contact.phoneNumbers.first(where: {
                let label = $0.label ?? ""
                return label.contains("Main") || label.contains("Home")
            })?.value.stringValue ?? contact.phoneNumbers.first?.value.stringValue
            
            let mobile = contact.phoneNumbers.first(where: {
                let label = $0.label ?? ""
                return label.contains("Mobile") || label.contains("iPhone")
            })?.value.stringValue
            
            let email = contact.emailAddresses.first?.value as String?
            
            var birthdayStr: String? = nil
            if let bday = contact.birthday, let date = Calendar.current.date(from: bday) {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                birthdayStr = fmt.string(from: date)
            }
            
            let nickname = contact.nickname.isEmpty ? nil : contact.nickname
            
            let input = CreatePersonInput(
                firstName: firstName,
                lastName: lastName,
                nickname: nickname,
                relationshipType: type,
                phone: phone,
                mobile: mobile,
                email: email,
                birthday: birthdayStr,
                userId: userId
            )
            
            do {
                _ = try await peopleManager.createPerson(input)
                success += 1
            } catch {
                print("❌ Failed to import \(firstName): \(error)")
            }
        }
        
        importingCount = 0
        importResult = (success: success, duplicates: duplicates)
        
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        importResult = nil
    }
    
    // MARK: - Import Overlays
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SorbetTheme.ViewTint.people.accent))
                    .scaleEffect(1.3)
                Text(L10n.shared.currentLanguage == .hebrew
                     ? "מייבא \(importingCount) אנשי קשר..."
                     : "Importing \(importingCount) contacts...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
            }
            .padding(30)
            .background(SorbetTheme.Palette.surface)
            .cornerRadius(16)
        }
    }
    
    private func importResultOverlay(_ result: (success: Int, duplicates: Int)) -> some View {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        return ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "10b981"))
                
                Text(isHebrew
                     ? "יובאו \(result.success) אנשי קשר"
                     : "\(result.success) contacts imported")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
                
                if result.duplicates > 0 {
                    Text(isHebrew
                         ? "\(result.duplicates) כבר קיימים (דולגו)"
                         : "\(result.duplicates) already existed (skipped)")
                        .font(.system(size: 14))
                        .foregroundColor(SorbetTheme.Palette.textSecondary)
                }
            }
            .padding(30)
            .background(SorbetTheme.Palette.surface)
            .cornerRadius(16)
        }
        .transition(.opacity)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.contacts)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
                
                Text(contactsCountText)
                    .font(.system(size: 14))
                    .foregroundColor(SorbetTheme.Palette.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { showingContactPicker = true }) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 22))
                        .foregroundColor(SorbetTheme.ViewTint.people.accent)
                }
                
                Button(action: { showingAddContact = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(SorbetTheme.ViewTint.people.accent)
                }
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
                    isSearchFocused = false
                    selectedFilter = nil
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "משפחה" : "Family",
                    icon: "house.fill",
                    isSelected: selectedFilter == .family
                ) {
                    isSearchFocused = false
                    selectedFilter = selectedFilter == .family ? nil : .family
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "חברים" : "Friends",
                    icon: "person.2.fill",
                    isSelected: selectedFilter == .friend
                ) {
                    isSearchFocused = false
                    selectedFilter = selectedFilter == .friend ? nil : .friend
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "עבודה" : "Work",
                    icon: "briefcase.fill",
                    isSelected: selectedFilter == .colleague
                ) {
                    isSearchFocused = false
                    selectedFilter = selectedFilter == .colleague ? nil : .colleague
                }
                
                FilterChip(
                    title: L10n.shared.currentLanguage == .hebrew ? "אחר" : "Other",
                    icon: "person.fill",
                    isSelected: selectedFilter == .other
                ) {
                    isSearchFocused = false
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
                .foregroundColor(SorbetTheme.Palette.textTertiary)
            
            TextField(
                L10n.shared.currentLanguage == .hebrew ? "חיפוש אנשי קשר..." : "Search contacts...",
                text: $searchText
            )
            .textFieldStyle(.plain)
            .foregroundColor(SorbetTheme.Palette.textPrimary)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .onSubmit {
                isSearchFocused = false
            }
            
            if !searchText.isEmpty {
                Button(action: { 
                    searchText = ""
                    isSearchFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(SorbetTheme.Palette.textTertiary)
                }
            }
        }
        .padding(12)
        .background(SorbetTheme.Palette.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SorbetTheme.Palette.border, lineWidth: 1)
        )
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
                        NavigationLink(destination: ContactDetailView(person: person)) {
                            ContactRowView(person: person)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            isSearchFocused = false
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
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
            }
            .padding(.top, 8)
            
            ForEach(upcomingBirthdays.prefix(3), id: \.id) { person in
                NavigationLink(destination: ContactDetailView(person: person)) {
                    UpcomingBirthdayRow(person: person)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.bottom, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(SorbetTheme.Palette.textTertiary)
            
            Text(L10n.shared.currentLanguage == .hebrew ? "לא נמצאו אנשי קשר" : "No contacts found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(SorbetTheme.Palette.textTertiary)
            
            if !searchText.isEmpty {
                Text(L10n.shared.currentLanguage == .hebrew ? "נסה לחפש משהו אחר" : "Try a different search")
                    .font(.system(size: 14))
                    .foregroundColor(SorbetTheme.Palette.textTertiary)
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
            .background(isSelected ? SorbetTheme.ViewTint.people.accent : SorbetTheme.Palette.surface)
            .foregroundColor(isSelected ? .white : SorbetTheme.Palette.textSecondary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : SorbetTheme.Palette.border, lineWidth: 1)
            )
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
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
                
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
        .sorbetCard(radius: 12)
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
            return SorbetTheme.ViewTint.people.accent // Purple
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
                    .foregroundColor(SorbetTheme.Palette.textPrimary)
                
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
                    .foregroundColor(SorbetTheme.Palette.textSecondary)
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

