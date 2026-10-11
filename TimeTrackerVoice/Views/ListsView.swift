import SwiftUI
import PhotosUI

/// The Lists tab: mobile equivalent of the web app's Backlog and Social Plans
/// sections. Two inboxes in one tab: Backlog (task_type == .idea) and Social Plans
/// (task_type == .social). Add items, tap to edit (social plans open a full
/// form with a link and photos), swipe to delete, or swipe to schedule
/// (promote into a dated task).
struct ListsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @ObservedObject private var l10n = L10n.shared

    enum Segment: String { case backlog, social }
    @AppStorage("listsSegment") private var segment: Segment = .backlog
    @State private var captureText: String = ""
    @State private var promoteItem: TaskItem?
    @State private var planForm: PlanForm?
    @ObservedObject private var attachments = AttachmentManager.shared
    @Environment(\.openURL) private var openURL

    private var he: Bool { l10n.currentLanguage == .hebrew }

    private var currentType: TaskType { segment == .backlog ? .idea : .social }

    private func items(of type: TaskType) -> [TaskItem] {
        taskManager.tasks
            .filter { $0.taskType == type }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var items: [TaskItem] { items(of: currentType) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    segmentPicker
                    addField
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                if items.isEmpty {
                    Section {
                        emptyState
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(items) { item in
                            row(item)
                        }
                    } header: {
                        Text(countHeader)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .background(NativePalette.background.ignoresSafeArea())
            .contentMargins(.bottom, 100, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await refresh() }
            .navigationTitle(L10n.tabLists)
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $promoteItem) { item in
                SchedulePlanSheet(item: item) { promoteItem = nil }
                    .environmentObject(taskManager)
            }
            .sheet(item: $planForm) { form in
                PlanFormSheet(form: form) { planForm = nil }
                    .environmentObject(taskManager)
            }
            .onAppear {
                Task { await refresh() }
            }
        }
        .tint(NativePalette.accent)
        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header controls

    private var segmentPicker: some View {
        Picker(he ? "רשימה" : "List", selection: $segment) {
            Text(segmentLabel(he ? "בקלוג" : "Backlog", count: items(of: .idea).count)).tag(Segment.backlog)
            Text(segmentLabel(he ? "בילויים" : "Social", count: items(of: .social).count)).tag(Segment.social)
        }
        .pickerStyle(.segmented)
    }

    private func segmentLabel(_ name: String, count: Int) -> String {
        count > 0 ? "\(name) \(count)" : name
    }

    private var addField: some View {
        HStack(spacing: 8) {
            TextField(addPlaceholder, text: $captureText)
                .font(.system(size: 16))
                .submitLabel(.done)
                .onSubmit(addItem)
            Button(action: addItem) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(NativePalette.accent))
            }
            .buttonStyle(.plain)
            .disabled(captureText.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(captureText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .accessibilityLabel(segment == .backlog ? (he ? "הוסף לבקלוג" : "Add to backlog") : (he ? "הוסף בילוי" : "Add plan"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(NativePalette.surface))
    }

    private var addPlaceholder: String {
        segment == .backlog ? (he ? "הוסף לבקלוג…" : "Add to backlog…") : (he ? "הוסף בילוי…" : "Add a plan…")
    }

    private var countHeader: String {
        let n = items.count
        if segment == .backlog {
            return he ? "\(n) פריטים" : (n == 1 ? "1 item" : "\(n) items")
        }
        return he ? "\(n) בילויים" : (n == 1 ? "1 plan" : "\(n) plans")
    }

    // MARK: - Rows

    private func row(_ item: TaskItem) -> some View {
        HStack(spacing: 12) {
            if item.taskType == .social {
                planTile(item)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NativePalette.ink)
                        .lineLimit(1)
                    if attachments.taskIdsWithAttachments.contains(item.id) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 13))
                            .foregroundStyle(NativePalette.muted)
                            .accessibilityLabel(he ? "יש קבצים" : "Has files")
                    }
                }
                if let d = item.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 14))
                        .foregroundStyle(NativePalette.muted)
                        .lineLimit(1)
                }
                if let link = item.linkUrl, let url = TaskLink.normalize(link) {
                    Button { openURL(url) } label: {
                        Label(TaskLink.label(for: url), systemImage: "link")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(NativePalette.accent)
                    .accessibilityLabel((he ? "פתח קישור: " : "Open link: ") + TaskLink.label(for: url))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { planForm = .edit(item) }
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deleteItem(item) } label: {
                Label(he ? "מחק" : "Delete", systemImage: "trash")
            }
            Button { promoteItem = item } label: {
                Label(he ? "קבע תאריך" : "Schedule", systemImage: "calendar")
            }
            .tint(.blue)
        }
    }

    /// First photo of a social plan, or a star tile when it has none.
    @ViewBuilder
    private func planTile(_ item: TaskItem) -> some View {
        Group {
            if let photo = attachments.firstImageByTask[item.id] {
                AttachmentThumbnail(attachment: photo)
                    .accessibilityLabel(he ? "תמונה" : "Photo")
            } else {
                ZStack {
                    NativePalette.background
                    Image(systemName: "star")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(NativePalette.accent)
                }
                .accessibilityHidden(true)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: segment == .backlog ? "tray" : "star")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(NativePalette.accent)
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(NativePalette.accentSoft))
            Text(segment == .backlog
                 ? (he ? "הבקלוג ריק" : "Your backlog is empty")
                 : (he ? "אין עדיין בילויים" : "No plans yet"))
                .font(.system(size: 20, weight: .semibold))
            Text(segment == .backlog
                 ? (he ? "רשום כאן דברים לעשות בלי תאריך — תקבע אותם כשתהיה מוכן"
                       : "Jot down things to do without a date, and schedule them when you're ready")
                 : (he ? "תפוס כאן רעיונות לבילויים ומפגשים — עם קישור ותמונות — לפני שתקבע להם תאריך"
                       : "Capture ideas for outings, with a link and photos, before you pick a date"))
                .font(.system(size: 15))
                .foregroundStyle(NativePalette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 16)
    }

    private func refresh() async {
        await taskManager.fetchTasks()
        await attachments.refreshIndex()
    }

    private func addItem() {
        let text = captureText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        captureText = ""
        if segment == .social {
            planForm = .new(type: .social, title: text)
            return
        }
        let today = Self.ymd(Date())
        var input = CreateTaskInput(title: text, date: today)
        input.taskType = currentType
        input.priority = .low
        input.userId = AuthManager.shared.currentUser?.id
        Task {
            do {
                _ = try await taskManager.createTask(input)
                await taskManager.fetchTasks()
            } catch {
                print("❌ add list item error: \(error)")
            }
        }
    }

    private func deleteItem(_ item: TaskItem) {
        Task {
            do {
                try await taskManager.deleteTask(id: item.id)
                await taskManager.fetchTasks()
            } catch {
                print("❌ delete list item error: \(error)")
            }
        }
    }

    static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

/// What the plan form is opened for.
enum PlanForm: Identifiable {
    case new(type: TaskType, title: String)
    case edit(TaskItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let item): return item.id
        }
    }
}

/// Creates or edits an inbox item: title and notes, plus a link and photos
/// (gallery or camera) for social plans.
struct PlanFormSheet: View {
    let onDone: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    @ObservedObject private var l10n = L10n.shared

    private let type: TaskType
    /// The saved task; nil until a new plan is first saved (a failed photo
    /// upload then retries against the same task instead of creating another).
    @State private var item: TaskItem?
    @State private var title: String
    @State private var notes: String
    @State private var link: String

    @State private var existingPhotos: [TaskAttachment] = []
    @State private var removedPhotoIds: Set<String> = []
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var preview: PreviewFile?

    @State private var saving = false
    @State private var errorMessage: String?

    init(form: PlanForm, onDone: @escaping () -> Void) {
        self.onDone = onDone
        switch form {
        case .new(let type, let title):
            self.type = type
            _item = State(initialValue: nil)
            _title = State(initialValue: title)
            _notes = State(initialValue: "")
            _link = State(initialValue: "")
        case .edit(let item):
            self.type = item.taskType
            _item = State(initialValue: item)
            _title = State(initialValue: item.title)
            _notes = State(initialValue: item.description ?? "")
            _link = State(initialValue: item.linkUrl ?? "")
        }
    }

    private var he: Bool { l10n.currentLanguage == .hebrew }
    private var isSocial: Bool { type == .social }
    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var linkIsValid: Bool { trimmedLink.isEmpty || TaskLink.normalize(trimmedLink) != nil }
    private var visibleExisting: [TaskAttachment] {
        existingPhotos.filter { $0.isImage && !removedPhotoIds.contains($0.id) }
    }
    private var canSave: Bool {
        !saving && !title.trimmingCharacters(in: .whitespaces).isEmpty && (!isSocial || linkIsValid)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(he ? "כותרת" : "Title")) {
                    TextField(he ? "כותרת" : "Title", text: $title)
                }
                Section(header: Text(he ? "פרטים" : "Details")) {
                    TextField(he ? "פרטים נוספים..." : "More details...", text: $notes)
                }
                if isSocial {
                    linkSection
                    photosSection
                }
            }
            .disabled(saving)
            .navigationTitle(item == nil ? (he ? "בילוי חדש" : "New plan") : (he ? "עריכה" : "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(he ? "ביטול" : "Cancel", action: onDone).disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button(he ? "שמור" : "Save", action: save).disabled(!canSave)
                    }
                }
            }
            .alert(
                he ? "שגיאה" : "Something went wrong",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button(he ? "אישור" : "OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
        .interactiveDismissDisabled(saving)
        .task { await loadExistingPhotos() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task { await addPicked(items) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(onImage: addCameraImage) { showCamera = false }
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $preview) { file in
            AttachmentPreview(fileURL: file.url) { preview = nil }
                .ignoresSafeArea()
        }
    }

    private var linkSection: some View {
        Section(
            header: Text(he ? "קישור" : "Link"),
            footer: linkIsValid ? nil : Text(he ? "הקישור לא תקין" : "This link is not valid")
                .foregroundColor(.red)
        ) {
            TextField(he ? "קישור לסרט, הצגה או מקום" : "Link to a movie, show or place", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .environment(\.layoutDirection, .leftToRight)
            if let url = TaskLink.normalize(trimmedLink) {
                Link(destination: url) {
                    Label(he ? "פתח קישור" : "Open link", systemImage: "safari")
                }
            }
        }
    }

    private var photosSection: some View {
        Section(header: Text(he ? "תמונות" : "Photos")) {
            if !visibleExisting.isEmpty || !pendingPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleExisting) { photo in
                            thumbnail(AttachmentThumbnail(attachment: photo), onTap: { open(photo) }) {
                                removedPhotoIds.insert(photo.id)
                            }
                        }
                        ForEach(pendingPhotos) { photo in
                            thumbnail(Image(uiImage: photo.thumbnail).resizable().scaledToFill(), onTap: nil) {
                                pendingPhotos.removeAll { $0.id == photo.id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                Label(he ? "בחר מהגלריה" : "Choose from gallery", systemImage: "photo.on.rectangle")
            }
            if CameraPicker.isAvailable {
                Button { showCamera = true } label: {
                    Label(he ? "צלם תמונה" : "Take photo", systemImage: "camera")
                }
            }
        }
    }

    private func thumbnail<Content: View>(
        _ content: Content, onTap: (() -> Void)?, onRemove: @escaping () -> Void
    ) -> some View {
        content
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .font(.system(size: 20))
                }
                .buttonStyle(.borderless)
                .padding(2)
                .accessibilityLabel(he ? "הסר תמונה" : "Remove photo")
            }
    }

    // MARK: - Photos

    private func loadExistingPhotos() async {
        guard isSocial, let id = item?.id else { return }
        existingPhotos = (try? await AttachmentManager.shared.attachments(for: id)) ?? []
    }

    private func addPicked(_ items: [PhotosPickerItem]) async {
        var failed = false
        for picked in items {
            guard let data = try? await picked.loadTransferable(type: Data.self),
                  let photo = await Task.detached(operation: { PendingPhoto.make(from: data) }).value else {
                failed = true
                continue
            }
            pendingPhotos.append(photo)
        }
        if failed { errorMessage = he ? "לא ניתן היה לטעון חלק מהתמונות" : "Some photos couldn't be loaded" }
    }

    private func addCameraImage(_ image: UIImage) {
        Task {
            if let photo = await Task.detached(operation: { PendingPhoto.make(from: image) }).value {
                pendingPhotos.append(photo)
            }
        }
    }

    private func open(_ photo: TaskAttachment) {
        Task {
            if let url = try? await AttachmentManager.shared.localFile(for: photo) {
                preview = PreviewFile(url: url)
            } else {
                errorMessage = he ? "לא ניתן לפתוח את התמונה" : "Couldn't open this photo"
            }
        }
    }

    // MARK: - Save

    private func save() {
        saving = true
        Task {
            defer { saving = false }
            let saved: TaskItem
            do {
                saved = try await saveTask()
                item = saved
            } catch {
                print("❌ save list item error: \(error)")
                errorMessage = he ? "לא ניתן היה לשמור" : "Couldn't save"
                return
            }

            var photoFailed = false
            for photo in existingPhotos where removedPhotoIds.contains(photo.id) {
                do {
                    try await AttachmentManager.shared.remove(photo)
                    existingPhotos.removeAll { $0.id == photo.id }
                    removedPhotoIds.remove(photo.id)
                } catch {
                    photoFailed = true
                }
            }
            for photo in pendingPhotos {
                do {
                    let uploaded = try await AttachmentManager.shared.uploadPhoto(photo.jpeg, taskId: saved.id)
                    existingPhotos.append(uploaded)
                    pendingPhotos.removeAll { $0.id == photo.id }
                } catch {
                    photoFailed = true
                }
            }
            await AttachmentManager.shared.refreshIndex()
            await taskManager.fetchTasks()

            if photoFailed {
                errorMessage = he
                    ? "הבילוי נשמר, אבל חלק מהתמונות לא עודכנו. לחץ שמור כדי לנסות שוב."
                    : "The plan was saved, but some photos couldn't upload. Tap Save to try again."
            } else {
                onDone()
            }
        }
    }

    private func saveTask() async throws -> TaskItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let newLink = isSocial ? TaskLink.normalize(trimmedLink)?.absoluteString : nil

        guard let item else {
            var input = CreateTaskInput(title: cleanTitle, date: ListsView.ymd(Date()))
            input.description = cleanNotes.isEmpty ? nil : cleanNotes
            input.taskType = type
            input.priority = .low
            input.userId = AuthManager.shared.currentUser?.id
            input.linkUrl = newLink
            return try await taskManager.createTask(input)
        }

        var input = UpdateTaskInput()
        input.title = cleanTitle
        if cleanNotes != (item.description ?? "") { input.description = cleanNotes }
        if isSocial && newLink != item.linkUrl { input.linkUrl = .some(newLink) }
        return try await taskManager.updateTask(id: item.id, input: input)
    }
}

/// Picks a date and promotes an inbox item into a scheduled task.
struct SchedulePlanSheet: View {
    let item: TaskItem
    let onDone: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    @ObservedObject private var l10n = L10n.shared
    @State private var date = Date()

    private var he: Bool { l10n.currentLanguage == .hebrew }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                Spacer()
            }
            .padding()
            .navigationTitle(he ? "קבע תאריך" : "Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(he ? "ביטול" : "Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(he ? "שמור" : "Save", action: promote)
                }
            }
        }
        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
    }

    private func promote() {
        var input = UpdateTaskInput()
        input.taskType = .task
        input.date = ListsView.ymd(date)
        input.status = .todo
        Task {
            do {
                _ = try await taskManager.updateTask(id: item.id, input: input)
                await taskManager.fetchTasks()
            } catch {
                print("❌ promote error: \(error)")
            }
            onDone()
        }
    }
}
