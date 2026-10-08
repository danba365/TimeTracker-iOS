import SwiftUI

/// Mobile equivalent of the web app's Backlog and Social Plans sections.
/// Two inboxes in one tab: Backlog (task_type == .idea) and Social Plans
/// (task_type == .social). Add items, swipe to delete, or swipe to schedule
/// (promote into a dated task).
struct ListsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @ObservedObject private var l10n = L10n.shared

    enum Segment { case backlog, social }
    @State private var segment: Segment = .backlog
    @State private var captureText: String = ""
    @State private var promoteItem: TaskItem?

    private var he: Bool { l10n.currentLanguage == .hebrew }

    private var currentType: TaskType { segment == .backlog ? .idea : .social }

    private var items: [TaskItem] {
        taskManager.tasks
            .filter { $0.taskType == currentType }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(he ? "רשימות" : "Lists")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Picker("", selection: $segment) {
                Text(he ? "בקלוג" : "Backlog").tag(Segment.backlog)
                Text(he ? "בילויים" : "Social").tag(Segment.social)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            HStack(spacing: 8) {
                TextField(he ? "הוסף לרשימה..." : "Add to the list...", text: $captureText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 28))
                }
                .disabled(captureText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if items.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text(segment == .backlog ? "🗂️" : "🎉").font(.system(size: 44))
                    Text(he ? "הרשימה ריקה" : "This list is empty")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.system(size: 16, weight: .medium))
                            if let d = item.description, !d.isEmpty {
                                Text(d).font(.system(size: 13)).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
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
                }
                .listStyle(.plain)
            }
        }
        .environment(\.layoutDirection, he ? .rightToLeft : .leftToRight)
        .sheet(item: $promoteItem) { item in
            SchedulePlanSheet(item: item) { promoteItem = nil }
                .environmentObject(taskManager)
        }
        .onAppear {
            Task { await taskManager.fetchTasks() }
        }
    }

    private func addItem() {
        let text = captureText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        captureText = ""
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
