import SwiftUI
import ContactsUI

/// Wraps CNContactPickerViewController for SwiftUI multi-select
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onSelectContacts: ([CNContact]) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = .clear
        return placeholder
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            picker.predicateForEnablingContact = NSPredicate(value: true)
            uiViewController.present(picker, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker
        
        init(_ parent: ContactPicker) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelectContacts(contacts)
            parent.isPresented = false
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

/// Sheet shown after picking contacts to assign relationship type before importing
struct ContactImportReviewView: View {
    let contacts: [CNContact]
    let onImport: ([(CNContact, RelationshipType)]) -> Void
    let onCancel: () -> Void
    
    @State private var assignments: [String: RelationshipType] = [:]
    @State private var globalType: RelationshipType = .other
    
    private let isHebrew = L10n.shared.currentLanguage == .hebrew
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    globalTypePicker
                    
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(contacts, id: \.identifier) { contact in
                                contactRow(contact)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(isHebrew ? "ייבוא אנשי קשר" : "Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isHebrew ? "ביטול" : "Cancel") { onCancel() }
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isHebrew ? "ייבוא \(contacts.count)" : "Import \(contacts.count)") {
                        let result = contacts.map { contact in
                            (contact, assignments[contact.identifier] ?? globalType)
                        }
                        onImport(result)
                    }
                    .foregroundColor(Color(hex: "a78bfa"))
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private var globalTypePicker: some View {
        VStack(spacing: 8) {
            Text(isHebrew ? "סוג ברירת מחדל לכולם:" : "Default type for all:")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "94a3b8"))
            
            HStack(spacing: 8) {
                ForEach(RelationshipType.allCases, id: \.rawValue) { type in
                    Button {
                        globalType = type
                        assignments = [:]
                    } label: {
                        Text(labelFor(type))
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(globalType == type ? Color(hex: "a78bfa") : Color.white.opacity(0.08))
                            .foregroundColor(globalType == type ? .white : Color(hex: "94a3b8"))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
    }
    
    private func contactRow(_ contact: CNContact) -> some View {
        let name = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
        let currentType = assignments[contact.identifier] ?? globalType
        
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "a78bfa").opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(String(contact.givenName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "a78bfa"))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? (isHebrew ? "ללא שם" : "No Name") : name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                if !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "64748b"))
                }
            }
            
            Spacer()
            
            Menu {
                ForEach(RelationshipType.allCases, id: \.rawValue) { type in
                    Button {
                        assignments[contact.identifier] = type
                    } label: {
                        Label(labelFor(type), systemImage: iconFor(type))
                    }
                }
            } label: {
                Text(labelFor(currentType))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorFor(currentType))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(colorFor(currentType).opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func labelFor(_ type: RelationshipType) -> String {
        switch type {
        case .family:   return isHebrew ? "משפחה" : "Family"
        case .friend:   return isHebrew ? "חברים" : "Friends"
        case .colleague: return isHebrew ? "עבודה" : "Work"
        case .other:    return isHebrew ? "אחר" : "Other"
        }
    }
    
    private func iconFor(_ type: RelationshipType) -> String {
        switch type {
        case .family:   return "house.fill"
        case .friend:   return "person.2.fill"
        case .colleague: return "briefcase.fill"
        case .other:    return "person.fill"
        }
    }
    
    private func colorFor(_ type: RelationshipType) -> Color {
        switch type {
        case .family:   return Color(hex: "f472b6")
        case .friend:   return Color(hex: "60a5fa")
        case .colleague: return Color(hex: "fbbf24")
        case .other:    return Color(hex: "a78bfa")
        }
    }
}
