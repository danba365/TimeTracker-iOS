import SwiftUI

/// Contact detail (design 5a/5b): large avatar, Call / Message / Email
/// tiles, grouped details and notes. Reads the live contact by id so it
/// refreshes after an edit.
struct ContactDetailView: View {
    let personId: String

    @EnvironmentObject var peopleManager: PeopleManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared
    @State private var showingEdit = false

    private var person: Person? {
        peopleManager.people.first { $0.id == personId }
    }

    var body: some View {
        ScrollView {
            if let person {
                VStack(spacing: 0) {
                    header(person)
                    actions(person)
                    details(person)
                    if let notes = Person.nonEmpty(person.notes) {
                        notesSection(notes)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        .background(NativePalette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(l10n.edit) { showingEdit = true }
                    .fontWeight(.semibold)
                    .disabled(person == nil)
            }
        }
        .sheet(isPresented: $showingEdit) {
            ContactFormSheet(person: person, onDeleted: { dismiss() })
                .environmentObject(peopleManager)
        }
        .tint(NativePalette.accent)
    }

    // MARK: - Header

    private func header(_ person: Person) -> some View {
        VStack(spacing: 0) {
            ContactAvatar(person: person, size: 96)

            Text(person.fullName)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            if let nickname = Person.nonEmpty(person.nickname) {
                Text("“\(nickname)”")
                    .font(.system(size: 17))
                    .foregroundStyle(NativePalette.muted)
                    .padding(.top, 2)
            }

            Label(person.subtitle ?? l10n.relationshipName(person.relationshipType),
                  systemImage: ContactStyle.icon(person.relationshipType))
                .font(.system(size: 15, weight: .semibold))
                .labelStyle(TightLabelStyle())
                .foregroundStyle(ContactStyle.avatarForeground(person.relationshipType))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(ContactStyle.avatarBackground(person.relationshipType), in: Capsule())
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ person: Person) -> some View {
        let number = person.callNumber
        let email = Person.nonEmpty(person.email)

        if number != nil || email != nil {
            HStack(spacing: 10) {
                if let number {
                    actionTile(l10n.call, icon: "phone.fill") { openURL("tel://\(dialable(number))") }
                    actionTile(l10n.message, icon: "message.fill") { openURL("sms://\(dialable(number))") }
                }
                if let email {
                    actionTile(l10n.email, icon: "envelope.fill") { openURL("mailto:\(email)") }
                }
            }
            .padding(.top, 22)
        }
    }

    private func actionTile(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(NativePalette.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details

    private struct DetailRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        var isSet = true
        var isLink = false
        var icon: String? = nil
        var url: String? = nil
    }

    private func detailRows(_ person: Person) -> [DetailRow] {
        var rows: [DetailRow] = []

        if let mobile = Person.nonEmpty(person.mobile) {
            rows.append(DetailRow(label: l10n.mobile, value: mobile, isLink: true, url: "tel://\(dialable(mobile))"))
        } else {
            rows.append(DetailRow(label: l10n.mobile, value: l10n.notSet, isSet: false))
        }

        if let phone = Person.nonEmpty(person.phone) {
            rows.append(DetailRow(label: l10n.phone, value: phone, isLink: true, url: "tel://\(dialable(phone))"))
        }

        if let email = Person.nonEmpty(person.email) {
            rows.append(DetailRow(label: l10n.email, value: email, isLink: true, url: "mailto:\(email)"))
        } else {
            rows.append(DetailRow(label: l10n.email, value: l10n.notSet, isSet: false))
        }

        if let birthday = Person.nonEmpty(person.birthday).flatMap(TasksView.isoDay.date(from:)) {
            var value = monthDay(birthday)
            if let days = person.daysUntilBirthday, days <= 30, let turning = person.turningAge {
                value += " · \(l10n.willTurn(turning)), \(birthdayWhen(days, l10n: l10n).lowercased())"
            } else if let age = person.age {
                value += " · \(l10n.ageLabel(age))"
            }
            rows.append(DetailRow(label: l10n.birthday, value: value, icon: "birthday.cake.fill"))
        }

        if let anniversary = Person.nonEmpty(person.anniversary).flatMap(TasksView.isoDay.date(from:)) {
            let formatter = DateFormatter()
            formatter.locale = l10n.locale
            formatter.setLocalizedDateFormatFromTemplate("MMMMdyyyy")
            rows.append(DetailRow(label: l10n.anniversary, value: formatter.string(from: anniversary), icon: "heart.fill"))
        }

        return rows
    }

    private func details(_ person: Person) -> some View {
        let rows = detailRows(person)
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Button {
                    if let url = row.url { openURL(url) }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.label)
                                .font(.system(size: 13))
                                .foregroundStyle(NativePalette.muted)
                            Text(row.value)
                                .font(.system(size: 17))
                                .foregroundStyle(row.isLink ? NativePalette.accent : (row.isSet ? NativePalette.ink : NativePalette.faint))
                                // Phone numbers and emails always read left-to-right.
                                .environment(\.layoutDirection, row.isLink ? .leftToRight : l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let icon = row.icon {
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .foregroundStyle(NativePalette.occasion)
                        }
                    }
                    .padding(.vertical, 11)
                    .padding(.trailing, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(row.url == nil)
                .overlay(alignment: .bottom) {
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color(uiColor: .separator))
                            .frame(height: 0.5)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.top, 22)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(l10n.notes)
                .font(.system(size: 15))
                .foregroundStyle(NativePalette.muted)
                .padding(.horizontal, 16)
            Text(notes)
                .font(.system(size: 17))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .padding(.top, 22)
    }

    private func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = l10n.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }
}

/// Icon and title with a small gap, for the relationship pill.
private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 13))
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(personId: "1")
            .environmentObject(PeopleManager.shared)
    }
}
