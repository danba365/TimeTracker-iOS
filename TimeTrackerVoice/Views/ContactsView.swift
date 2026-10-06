import SwiftUI
import Contacts

// MARK: - Contact Style
// Relationship colours from design 5a/5b: pink family, blue friends,
// orange work, violet other. Each has a light and dark variant.

enum ContactStyle {
    static func avatarForeground(_ type: RelationshipType) -> Color {
        switch type {
        case .family: return Color(light: 0xD70040, dark: 0xFF6482)
        case .friend: return Color(light: 0x0062CC, dark: 0x64B5FF)
        case .colleague: return Color(light: 0xA84B00, dark: 0xFFB340)
        case .other: return Color(light: 0x7C3AED, dark: 0xC4B5FD)
        }
    }

    static func avatarBackground(_ type: RelationshipType) -> Color {
        switch type {
        case .family: return Color(light: 0xFF2D55, lightAlpha: 0.13, dark: 0xFF375F, darkAlpha: 0.22)
        case .friend: return Color(light: 0x007AFF, lightAlpha: 0.12, dark: 0x0A84FF, darkAlpha: 0.24)
        case .colleague: return Color(light: 0xFF9500, lightAlpha: 0.16, dark: 0xFF9F0A, darkAlpha: 0.20)
        case .other: return Color(light: 0x7C3AED, lightAlpha: 0.12, dark: 0xA78BFA, darkAlpha: 0.22)
        }
    }

    static func icon(_ type: RelationshipType) -> String {
        switch type {
        case .family: return "house.fill"
        case .friend: return "person.2.fill"
        case .colleague: return "briefcase.fill"
        case .other: return "person.fill"
        }
    }

    /// Text on a filled accent chip (white in light mode, black in dark mode).
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x000000)
}

extension Person {
    /// Optional text fields can come back as "" after an edit clears them.
    static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return text
    }

    var subtitle: String? { Person.nonEmpty(relationshipDetail) }

    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName?.prefix(1).uppercased() ?? ""
        return first + last
    }

    /// Mobile first, then landline.
    var callNumber: String? {
        Person.nonEmpty(mobile) ?? Person.nonEmpty(phone)
    }

    /// Age they will turn on their next birthday.
    var turningAge: Int? {
        guard let days = daysUntilBirthday, let age else { return nil }
        return days == 0 ? age : age + 1
    }
}

/// "Today" / "Tomorrow" / "In 7 days"
func birthdayWhen(_ days: Int, l10n: L10n) -> String {
    switch days {
    case 0: return L10n.today
    case 1: return L10n.tomorrow
    default: return l10n.inDays(days)
    }
}

func openURL(_ string: String) {
    if let url = URL(string: string) { UIApplication.shared.open(url) }
}

func dialable(_ number: String) -> String {
    number.filter { $0.isNumber || $0 == "+" }
}

// MARK: - Contacts View

/// Contacts tab (design 5a/5b): search, relationship filters, upcoming
/// birthday cards, and A–Z grouped lists with a one-tap call button.
struct ContactsView: View {
    @EnvironmentObject var peopleManager: PeopleManager
    @ObservedObject private var l10n = L10n.shared

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

        if let filter = selectedFilter {
            people = people.filter { $0.relationshipType == filter }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            people = people.filter { person in
                [person.fullName, person.nickname ?? "", person.relationshipDetail ?? ""]
                    .contains { $0.lowercased().contains(query) }
            }
        }

        return people.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
    }

    /// Contacts grouped by the first letter of their first name.
    private var sections: [(letter: String, people: [Person])] {
        var result: [(letter: String, people: [Person])] = []
        for person in filteredPeople {
            let letter = String(person.firstName.prefix(1)).uppercased()
            if result.last?.letter == letter {
                result[result.count - 1].people.append(person)
            } else {
                result.append((letter, [person]))
            }
        }
        return result
    }

    private var upcomingBirthdays: [Person] {
        peopleManager.getUpcomingBirthdays(days: 30)
    }

    private var showComingUp: Bool {
        selectedFilter == nil && searchText.isEmpty && !upcomingBirthdays.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    controls
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                if showComingUp {
                    Section {
                        comingUpCards
                            .listRowInsets(EdgeInsets())
                    } header: {
                        sectionTitle(l10n.comingUp)
                    }
                    .listRowBackground(Color.clear)
                }

                if filteredPeople.isEmpty && !peopleManager.isLoading {
                    Section {
                        emptyState
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(sections, id: \.letter) { section in
                    Section {
                        ForEach(section.people) { person in
                            NavigationLink(value: person.id) {
                                ContactRowView(person: person)
                            }
                        }
                    } header: {
                        sectionTitle(section.letter)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .background(NativePalette.background.ignoresSafeArea())
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await peopleManager.fetchPeople() }
            .navigationTitle(L10n.contacts)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { id in
                ContactDetailView(personId: id)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingContactPicker = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel(l10n.importContacts)

                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(l10n.newContact)
                }
            }
            .onAppear {
                Task { await peopleManager.fetchPeople() }
            }
            .sheet(isPresented: $showingAddContact) {
                ContactFormSheet(person: nil)
                    .environmentObject(peopleManager)
            }
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
        .tint(NativePalette.accent)
    }

    // MARK: - Header controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.peopleCount(filteredPeople.count))
                .font(.system(size: 15))
                .foregroundStyle(NativePalette.muted)
                .padding(.horizontal, 4)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(NativePalette.muted)
                TextField(l10n.searchPlaceholder, text: $searchText)
                    .font(.system(size: 17))
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(NativePalette.muted)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(NativePalette.segment, in: Capsule())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(l10n.filterAll, icon: nil, value: nil)
                    filterChip(l10n.filterFamily, icon: ContactStyle.icon(.family), value: .family)
                    filterChip(l10n.filterFriends, icon: ContactStyle.icon(.friend), value: .friend)
                    filterChip(l10n.filterWork, icon: ContactStyle.icon(.colleague), value: .colleague)
                    filterChip(l10n.filterOther, icon: ContactStyle.icon(.other), value: .other)
                }
            }
            .scrollClipDisabled()
        }
        .padding(.bottom, 4)
    }

    private func filterChip(_ title: String, icon: String?, value: RelationshipType?) -> some View {
        let isSelected = selectedFilter == value
        return Button {
            isSearchFocused = false
            withAnimation(.snappy) { selectedFilter = value }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(isSelected ? ContactStyle.onAccent : NativePalette.ink)
            .background(isSelected ? NativePalette.accent : NativePalette.segment, in: Capsule())
        }
        .buttonStyle(.borderless)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(NativePalette.ink)
            .textCase(nil)
    }

    // MARK: - Coming up

    private var comingUpCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(upcomingBirthdays) { person in
                    NavigationLink(value: person.id) {
                        BirthdayCard(person: person)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(NativePalette.faint)
            Text(l10n.noContacts)
                .font(.system(size: 17, weight: .semibold))
            Text(l10n.noContactsSub)
                .font(.system(size: 15))
                .foregroundStyle(NativePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
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
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                Text(l10n.importingContacts(importingCount))
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(30)
            .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private func importResultOverlay(_ result: (success: Int, duplicates: Int)) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(NativePalette.done)
                Text(l10n.contactsImported(result.success))
                    .font(.system(size: 17, weight: .semibold))
                if result.duplicates > 0 {
                    Text(l10n.duplicatesSkipped(result.duplicates))
                        .font(.system(size: 15))
                        .foregroundStyle(NativePalette.muted)
                }
            }
            .padding(30)
            .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .transition(.opacity)
    }
}

// MARK: - Avatar

struct ContactAvatar: View {
    let person: Person
    let size: CGFloat

    var body: some View {
        Text(person.initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(ContactStyle.avatarForeground(person.relationshipType))
            .frame(width: size, height: size)
            .background(Circle().fill(ContactStyle.avatarBackground(person.relationshipType)))
    }
}

// MARK: - Contact Row

struct ContactRowView: View {
    let person: Person
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(person: person, size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(person.fullName)
                    .font(.system(size: 17))
                    .foregroundStyle(NativePalette.ink)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(person.subtitle ?? l10n.relationshipName(person.relationshipType))
                        .foregroundStyle(NativePalette.muted)
                    if let days = person.daysUntilBirthday, days <= 7 {
                        Text("· \(birthdayWhen(days, l10n: l10n))")
                            .foregroundStyle(NativePalette.occasion)
                    }
                }
                .font(.system(size: 15))
                .lineLimit(1)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 8)

            if let number = person.callNumber {
                Button {
                    openURL("tel://\(dialable(number))")
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(NativePalette.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(NativePalette.accentSoft))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(l10n.call)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Birthday Card

struct BirthdayCard: View {
    let person: Person
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ContactAvatar(person: person, size: 44)
                Spacer()
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(NativePalette.occasion)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(person.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NativePalette.ink)
                    .lineLimit(1)
                if let days = person.daysUntilBirthday {
                    Text(birthdayWhen(days, l10n: l10n))
                        .font(.system(size: 15))
                        .foregroundStyle(NativePalette.occasion)
                }
                if let turning = person.turningAge {
                    Text(l10n.willTurn(turning))
                        .font(.system(size: 13))
                        .foregroundStyle(NativePalette.muted)
                }
            }
        }
        .padding(14)
        .frame(width: 150, alignment: .leading)
        .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Contact Form (add / edit)

struct ContactFormSheet: View {
    /// nil = create a new contact.
    let person: Person?
    var onDeleted: (() -> Void)? = nil

    @EnvironmentObject var peopleManager: PeopleManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var relationshipType: RelationshipType = .friend
    @State private var relationshipDetail = ""
    @State private var mobile = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var notes = ""
    @State private var isSaving = false
    @State private var failed = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(l10n.firstName, text: $firstName)
                    TextField(l10n.lastName, text: $lastName)
                    TextField(l10n.nickname, text: $nickname)
                }

                Section(l10n.relationship) {
                    Picker(l10n.relationship, selection: $relationshipType) {
                        ForEach(RelationshipType.allCases, id: \.self) { type in
                            Text(l10n.relationshipName(type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField(l10n.relationshipDetail, text: $relationshipDetail)
                }

                Section {
                    TextField(l10n.mobile, text: $mobile)
                        .keyboardType(.phonePad)
                    TextField(l10n.phone, text: $phone)
                        .keyboardType(.phonePad)
                    TextField(l10n.email, text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Toggle(l10n.hasBirthday, isOn: $hasBirthday.animation())
                    if hasBirthday {
                        DatePicker(l10n.birthday, selection: $birthday, displayedComponents: .date)
                    }
                }

                Section(l10n.notes) {
                    TextField(l10n.notes, text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if failed {
                    Text(l10n.saveFailed)
                        .foregroundStyle(NativePalette.high)
                }

                if person != nil {
                    Section {
                        Button(l10n.deleteContact, role: .destructive) {
                            confirmingDelete = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(person == nil ? l10n.newContact : l10n.editContact)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) { save() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .confirmationDialog(l10n.deleteConfirmMessage, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button(l10n.delete, role: .destructive) { delete() }
            }
            .onAppear(perform: load)
        }
        .tint(NativePalette.accent)
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
    }

    private func load() {
        guard let person else { return }
        firstName = person.firstName
        lastName = person.lastName ?? ""
        nickname = person.nickname ?? ""
        relationshipType = person.relationshipType
        relationshipDetail = person.relationshipDetail ?? ""
        mobile = person.mobile ?? ""
        phone = person.phone ?? ""
        email = person.email ?? ""
        notes = person.notes ?? ""
        if let date = person.birthday.flatMap(TasksView.isoDay.date(from:)) {
            hasBirthday = true
            birthday = date
        }
    }

    private func value(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func save() {
        isSaving = true
        failed = false
        let birthdayString = hasBirthday ? TasksView.isoDay.string(from: birthday) : nil

        Task {
            do {
                if let person {
                    var input = UpdatePersonInput()
                    input.firstName = value(firstName)
                    // Empty strings (not nil) so a cleared field is saved as cleared.
                    input.lastName = value(lastName) ?? ""
                    input.nickname = value(nickname) ?? ""
                    input.relationshipType = relationshipType
                    input.relationshipDetail = value(relationshipDetail) ?? ""
                    input.mobile = value(mobile) ?? ""
                    input.phone = value(phone) ?? ""
                    input.email = value(email) ?? ""
                    input.birthday = birthdayString
                    input.notes = value(notes) ?? ""
                    _ = try await peopleManager.updatePerson(id: person.id, input: input)
                } else {
                    let input = CreatePersonInput(
                        firstName: value(firstName) ?? firstName,
                        lastName: value(lastName),
                        nickname: value(nickname),
                        relationshipType: relationshipType,
                        relationshipDetail: value(relationshipDetail),
                        phone: value(phone),
                        mobile: value(mobile),
                        email: value(email),
                        birthday: birthdayString,
                        notes: value(notes),
                        userId: AuthManager.shared.currentUser?.id
                    )
                    _ = try await peopleManager.createPerson(input)
                }
                dismiss()
            } catch {
                print("❌ Failed to save contact: \(error)")
                failed = true
            }
            isSaving = false
        }
    }

    private func delete() {
        guard let person else { return }
        Task {
            do {
                try await peopleManager.deletePerson(id: person.id)
                dismiss()
                onDeleted?()
            } catch {
                print("❌ Failed to delete contact: \(error)")
                failed = true
            }
        }
    }
}

#Preview {
    ContactsView()
        .environmentObject(PeopleManager.shared)
}
