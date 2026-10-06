import SwiftUI

// MARK: - Native Palette
// "iOS 26 native" direction (design option 4): system label / grouped
// background colors, system red / orange / green / pink / cyan, and the app
// violet as tint. Every color adapts to light and dark mode.

enum NativePalette {
    static let accent = Color(light: 0x7C3AED, dark: 0xA78BFA)
    static let accentSoft = Color(light: 0x7C3AED, lightAlpha: 0.12, dark: 0xA78BFA, darkAlpha: 0.18)
    static let reminder = Color(light: 0x0091B0, dark: 0x3CD3FE)
    static let occasion = Color(light: 0xE0245E, dark: 0xFF375F)
    static let done = Color(uiColor: .systemGreen)
    static let high = Color(uiColor: .systemRed)
    static let medium = Color(light: 0xE08600, dark: 0xFF9F0A)
    static let low = Color(light: 0x28A745, dark: 0x30D158)

    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let faint = Color(uiColor: .tertiaryLabel)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let segment = Color(uiColor: .tertiarySystemFill)

    static func priority(_ priority: Priority) -> Color {
        switch priority {
        case .high: return high
        case .medium: return medium
        case .low: return low
        }
    }
}

extension Color {
    /// A color that resolves to a different hex value in light and dark mode.
    init(light: UInt32, lightAlpha: CGFloat = 1, dark: UInt32, darkAlpha: CGFloat = 1) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let hex = isDark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }
}

// MARK: - Agenda Item

/// One row in the agenda: a task, reminder, birthday or event, normalized for display.
struct AgendaItem: Identifiable {
    enum Kind { case task, reminder, birthday, event }

    let id: String
    let kind: Kind
    let title: String
    let meta: String
    let metaColor: Color
    let startTime: String?  // HH:mm
    let endTime: String?    // HH:mm
    let isDone: Bool
    let isRecurring: Bool
    let eventType: EventType?
    let task: TaskItem?

    var hasTime: Bool { startTime != nil }
    var isOccasion: Bool { kind == .birthday || kind == .event }

    var startMinutes: Int? {
        guard let parts = startTime?.split(separator: ":"), parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    var timeRange: String {
        guard let start = startTime else { return "" }
        guard let end = endTime else { return start }
        return "\(start) – \(end)"
    }
}

// MARK: - Tasks View

/// Tasks tab: a week agenda (design 4a/4b) and a focused day view with
/// "Up next" (design 4c/4d). The toolbar pill switches between them.
struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    @EnvironmentObject var eventManager: EventManager
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var l10n = L10n.shared

    enum Mode: String { case week, day }

    @AppStorage("tasks_view_mode") private var mode: Mode = .week
    @State private var weekStart = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showDone = false
    @State private var showingAddTask = false
    @State private var openedTask: TaskItem?
    @State private var now = Date()

    private let calendar = Calendar.current
    private let minuteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            List {
                switch mode {
                case .week: weekContent
                case .day: dayContent
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .background(NativePalette.background.ignoresSafeArea())
            .contentMargins(.bottom, 100, for: .scrollContent)
            .refreshable { await refreshData() }
            .navigationTitle(mode == .week ? weekTitle : dayTitle(selectedDate))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .navigationDestination(item: $openedTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $showingAddTask) {
                NewTaskSheet(defaultDate: mode == .day ? selectedDate : Date())
                    .environmentObject(taskManager)
            }
            .onAppear {
                Task { await taskManager.fetchTasks() }
            }
            .onReceive(minuteTimer) { now = $0 }
        }
        .tint(NativePalette.accent)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            switch mode {
            case .week:
                Button(L10n.today) { openDay(Date()) }
                    .fontWeight(.semibold)
            case .day:
                if !calendar.isDateInToday(selectedDate) {
                    Button(L10n.today) { openDay(Date()) }
                        .fontWeight(.semibold)
                }
                Button(l10n.weekView) {
                    withAnimation { mode = .week }
                }
                .fontWeight(.semibold)
            }

            Button {
                showingAddTask = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(l10n.newTask)
        }
    }

    // MARK: - Week (4a / 4b)

    @ViewBuilder
    private var weekContent: some View {
        Section {
            headerSubtitle(weekRangeText)
        }
        .listRowBackground(Color.clear)

        ForEach(weekDays, id: \.self) { day in
            let items = agendaItems(for: day)
            let tasks = items.filter { $0.kind == .task }

            Section {
                if items.isEmpty {
                    Text(L10n.noTasksTitle)
                        .font(.system(size: 15))
                        .foregroundStyle(NativePalette.faint)
                        .padding(.vertical, 4)
                } else {
                    ForEach(items) { item in
                        agendaRow(item)
                    }
                }
            } header: {
                Button {
                    openDay(day)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(dayTitle(day))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(calendar.isDateInToday(day) ? NativePalette.accent : NativePalette.ink)
                        Text(format(day, template: "MMMMd"))
                            .font(.system(size: 17))
                            .foregroundStyle(NativePalette.muted)
                        Spacer()
                        if !tasks.isEmpty {
                            Text("\(tasks.filter(\.isDone).count)/\(tasks.count)")
                                .font(.system(size: 15))
                                .foregroundStyle(NativePalette.muted)
                                .monospacedDigit()
                        }
                    }
                    .textCase(nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Day (4c / 4d)

    @ViewBuilder
    private var dayContent: some View {
        let items = agendaItems(for: selectedDate)
        let focus = DayFocus(items: items, isToday: calendar.isDateInToday(selectedDate), now: now, calendar: calendar)

        Section {
            headerSubtitle(format(selectedDate, template: "EEEEMMMMd"))
            dayStrip
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)

        if items.isEmpty {
            Section {
                VStack(spacing: 4) {
                    Text(L10n.noTasksTitle)
                        .font(.system(size: 20, weight: .semibold))
                    Text(L10n.noTasksSubtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(NativePalette.muted)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            }
            .listRowBackground(Color.clear)
        }

        if let hero = focus.hero {
            Section {
                heroCard(hero, startsIn: focus.heroBadge(l10n: l10n))
                    .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)
        }

        if !focus.taskSegments.isEmpty {
            Section {
                progressBar(focus.taskSegments)
            }
            .listRowBackground(Color.clear)
        }

        if !focus.later.isEmpty {
            Section(calendar.isDateInToday(selectedDate) ? l10n.laterToday : l10n.later) {
                ForEach(focus.later) { agendaRow($0) }
            }
        }

        if !focus.anytime.isEmpty {
            Section(l10n.anytime) {
                ForEach(focus.anytime) { agendaRow($0) }
            }
        }

        if !focus.done.isEmpty {
            Section {
                if showDone {
                    ForEach(focus.done) { agendaRow($0) }
                }
            } header: {
                Button {
                    withAnimation { showDone.toggle() }
                } label: {
                    HStack {
                        Text("\(l10n.completedSection) · \(focus.done.count)")
                        Spacer()
                        Image(systemName: showDone ? "chevron.up" : "chevron.down")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(day)
                let marks = dayMarks(day)

                Button {
                    withAnimation(.snappy) { selectedDate = day }
                } label: {
                    VStack(spacing: 6) {
                        Text(weekdayLetter(day))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(NativePalette.muted)
                        Text(format(day, template: "d"))
                            .font(.system(size: 20, weight: isSelected || isToday ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : (isToday ? NativePalette.accent : NativePalette.ink))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(isSelected ? NativePalette.accent : .clear))
                        HStack(spacing: 3) {
                            if marks.hasItems {
                                Circle().fill(NativePalette.faint).frame(width: 5, height: 5)
                            }
                            if marks.hasOccasion {
                                Circle().fill(NativePalette.occasion).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    // Swipe toward the trailing edge goes back a week (mirrored in RTL).
                    var forward = value.translation.width < 0
                    if l10n.currentLanguage.isRTL { forward.toggle() }
                    shiftWeek(by: forward ? 7 : -7)
                }
        )
    }

    private func heroCard(_ hero: AgendaItem, startsIn: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l10n.upNext)
                    .font(.system(size: 13, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(NativePalette.accent)
                Spacer()
                Text(startsIn)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NativePalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(NativePalette.accentSoft, in: Capsule())
            }

            Text(hero.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(NativePalette.ink)
                .padding(.top, 16)

            Text([hero.timeRange, hero.meta].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 17))
                .foregroundStyle(NativePalette.muted)
                .padding(.top, 4)

            Button {
                if let task = hero.task { setStatus(task, done: true) }
            } label: {
                Label(l10n.markDone, systemImage: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(NativePalette.accent)
                    .background(NativePalette.accentSoft, in: Capsule())
            }
            .buttonStyle(.borderless)
            .padding(.top, 20)
        }
        .padding(22)
        .background(NativePalette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(NativePalette.accentSoft, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { openedTask = hero.task }
    }

    private func progressBar(_ segments: [Bool]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, isDone in
                Capsule()
                    .fill(isDone ? NativePalette.done : NativePalette.segment)
                    .frame(height: 4)
            }
            Text(l10n.progress(done: segments.filter { $0 }.count, total: segments.count))
                .font(.system(size: 13))
                .foregroundStyle(NativePalette.muted)
                .fixedSize()
                .padding(.leading, 6)
        }
    }

    // MARK: - Shared rows

    private func headerSubtitle(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !networkMonitor.isConnected {
                Label(L10n.offlineMode, systemImage: "wifi.slash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NativePalette.medium)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(NativePalette.muted)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
    }

    @ViewBuilder
    private func agendaRow(_ item: AgendaItem) -> some View {
        AgendaRowView(item: item) {
            if let task = item.task { setStatus(task, done: !item.isDone) }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let task = item.task { openedTask = task }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let task = item.task {
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label(l10n.delete, systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let task = item.task {
                Button {
                    setStatus(task, done: !item.isDone)
                } label: {
                    Label(item.isDone ? l10n.undone : l10n.markDone,
                          systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(item.isDone ? .orange : NativePalette.done)
            }
        }
    }

    // MARK: - Actions

    private func openDay(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        withAnimation {
            selectedDate = day
            if !weekDays.contains(day) || calendar.isDateInToday(day) {
                weekStart = day
            }
            mode = .day
        }
    }

    private func shiftWeek(by days: Int) {
        guard let start = calendar.date(byAdding: .day, value: days, to: weekStart),
              let selected = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        withAnimation(.snappy) {
            weekStart = start
            selectedDate = selected
        }
    }

    private func setStatus(_ task: TaskItem, done: Bool) {
        Task {
            _ = try? await taskManager.updateTask(id: task.id, input: UpdateTaskInput(status: done ? .done : .todo))
        }
    }

    private func deleteTask(_ task: TaskItem) {
        Task {
            do {
                try await taskManager.deleteTask(id: task.id)
            } catch {
                print("❌ Failed to delete task: \(error)")
            }
        }
    }

    private func refreshData() async {
        await taskManager.fetchTasks()
        await taskManager.fetchCategories()
        await peopleManager.fetchPeople()
        await eventManager.fetchEvents()
    }

    // MARK: - Data

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Reminders first, then birthdays and events, then tasks by time (untimed last).
    private func agendaItems(for date: Date) -> [AgendaItem] {
        let dateString = Self.isoDay.string(from: date)
        let dayTasks = taskManager.tasks.filter {
            $0.date == dateString && $0.taskType != .idea && $0.taskType != .social
        }

        let byTime: (TaskItem, TaskItem) -> Bool = { a, b in
            switch (a.startTime, b.startTime) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            default: return false
            }
        }

        let reminders = dayTasks.filter { $0.taskType == .reminder }.sorted(by: byTime).map { task in
            AgendaItem(
                id: task.id, kind: .reminder, title: task.title,
                meta: L10n.reminder, metaColor: NativePalette.reminder,
                startTime: Self.shortTime(task.startTime), endTime: Self.shortTime(task.endTime),
                isDone: task.status == .done, isRecurring: task.isRecurring || task.parentTaskId != nil,
                eventType: nil, task: task
            )
        }

        let tasks = dayTasks.filter { $0.taskType == .task }.sorted(by: byTime).map { task in
            AgendaItem(
                id: task.id, kind: .task, title: task.title,
                meta: l10n.priorityName(task.priority), metaColor: NativePalette.priority(task.priority),
                startTime: Self.shortTime(task.startTime), endTime: Self.shortTime(task.endTime),
                isDone: task.status == .done, isRecurring: task.isRecurring || task.parentTaskId != nil,
                eventType: nil, task: task
            )
        }

        let year = calendar.component(.year, from: date)

        let events = eventManager.getEventsForDate(date).map { event in
            var meta = event.eventType.displayName
            if let since = event.year, year - since > 0 {
                meta += " · \(l10n.yearsCount(year - since))"
            }
            return AgendaItem(
                id: "event-\(event.id)", kind: .event, title: event.name,
                meta: meta, metaColor: NativePalette.occasion,
                startTime: nil, endTime: nil, isDone: false, isRecurring: false,
                eventType: event.eventType, task: nil
            )
        }

        let birthdays = birthdayPeople(on: date).map { person in
            var parts: [String] = []
            if let relation = person.relationshipDetail ?? relationshipLabel(person.relationshipType) {
                parts.append(relation)
            }
            if let birthday = person.birthday.flatMap(Self.isoDay.date(from:)) {
                let turning = year - calendar.component(.year, from: birthday)
                if turning > 0 { parts.append(l10n.turning(turning)) }
            }
            return AgendaItem(
                id: "birthday-\(person.id)", kind: .birthday, title: l10n.birthdayTitle(person.fullName),
                meta: parts.joined(separator: " · "), metaColor: NativePalette.occasion,
                startTime: nil, endTime: nil, isDone: false, isRecurring: false,
                eventType: nil, task: nil
            )
        }

        return reminders + birthdays + events + tasks
    }

    private func birthdayPeople(on date: Date) -> [Person] {
        let target = calendar.dateComponents([.day, .month], from: date)
        return peopleManager.people.filter { person in
            guard let birthday = person.birthday.flatMap(Self.isoDay.date(from:)) else { return false }
            let parts = calendar.dateComponents([.day, .month], from: birthday)
            return parts.day == target.day && parts.month == target.month
        }
    }

    private func dayMarks(_ date: Date) -> (hasItems: Bool, hasOccasion: Bool) {
        let dateString = Self.isoDay.string(from: date)
        let hasItems = taskManager.tasks.contains {
            $0.date == dateString && $0.taskType != .idea && $0.taskType != .social
        }
        let hasOccasion = eventManager.hasEventOnDate(date) || !birthdayPeople(on: date).isEmpty
        return (hasItems, hasOccasion)
    }

    private func relationshipLabel(_ type: RelationshipType) -> String? {
        let he = l10n.currentLanguage == .hebrew
        switch type {
        case .family: return he ? "משפחה" : "Family"
        case .friend: return he ? "חבר" : "Friend"
        case .colleague: return he ? "עמית" : "Colleague"
        case .other: return nil
        }
    }

    // MARK: - Formatting

    private var weekTitle: String {
        weekDays.contains { calendar.isDateInToday($0) } ? l10n.thisWeek : l10n.weekView
    }

    private var weekRangeText: String {
        guard let last = weekDays.last else { return "" }
        let formatter = DateIntervalFormatter()
        formatter.locale = l10n.locale
        formatter.dateTemplate = "MMMMdyyyy"
        return formatter.string(from: weekStart, to: last)
    }

    private func dayTitle(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return L10n.today }
        if calendar.isDateInTomorrow(date) { return L10n.tomorrow }
        if calendar.isDateInYesterday(date) { return L10n.yesterday }
        return format(date, template: "EEEE")
    }

    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = l10n.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private func weekdayLetter(_ date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let letters = l10n.currentLanguage == .hebrew
            ? ["א", "ב", "ג", "ד", "ה", "ו", "ש"]
            : ["S", "M", "T", "W", "T", "F", "S"]
        return letters[weekday - 1]
    }

    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "HH:MM:SS" → "HH:MM"
    static func shortTime(_ time: String?) -> String? {
        guard let time, !time.isEmpty else { return nil }
        let parts = time.split(separator: ":")
        return parts.count >= 2 ? "\(parts[0]):\(parts[1])" : time
    }
}

// MARK: - Day Focus

/// Splits a day's items the way the "Up next" design does: one hero item,
/// timed items later in the day, untimed items and occasions, and done items.
private struct DayFocus {
    let hero: AgendaItem?
    let later: [AgendaItem]
    let anytime: [AgendaItem]
    let done: [AgendaItem]
    let taskSegments: [Bool]
    private let minutesUntilHero: Int?

    init(items: [AgendaItem], isToday: Bool, now: Date, calendar: Calendar) {
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let open = items.filter { !$0.isDone && !$0.isOccasion }
        let timedOpen = open.filter(\.hasTime)

        // Today: the first timed item that hasn't started more than 15 min ago.
        var hero = isToday
            ? timedOpen.first { ($0.startMinutes ?? 0) >= nowMinutes - 15 }
            : timedOpen.first
        if hero == nil { hero = open.first }
        self.hero = hero

        if isToday, let start = hero?.startMinutes {
            minutesUntilHero = start - nowMinutes
        } else {
            minutesUntilHero = nil
        }

        let rest = items.filter { !$0.isDone && $0.id != hero?.id }
        later = rest.filter { $0.hasTime && !$0.isOccasion }
        anytime = rest.filter { !$0.hasTime || $0.isOccasion }
        done = items.filter(\.isDone)
        taskSegments = items.filter { $0.kind == .task }.map(\.isDone)
    }

    func heroBadge(l10n: L10n) -> String {
        guard let hero else { return "" }
        if let minutes = minutesUntilHero {
            return minutes <= 0 ? l10n.now : l10n.startsIn(minutes: minutes)
        }
        return hero.startTime ?? l10n.anytime
    }
}

// MARK: - Agenda Row

struct AgendaRowView: View {
    let item: AgendaItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            leadingIcon
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 17))
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? NativePalette.faint : NativePalette.ink)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !item.meta.isEmpty {
                        Text(item.meta)
                            .font(.system(size: 15))
                            .foregroundStyle(item.metaColor)
                    }
                    if item.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NativePalette.muted)
                    }
                }
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 8)

            if let time = item.startTime {
                Text(time)
                    .font(.system(size: 17))
                    .foregroundStyle(NativePalette.muted)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch item.kind {
        case .task:
            Button(action: onToggle) {
                ZStack {
                    if item.isDone {
                        Circle().fill(NativePalette.done)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle().strokeBorder(NativePalette.faint, lineWidth: 1.5)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(.borderless)
        case .reminder:
            Image(systemName: "bell.fill")
                .font(.system(size: 20))
                .foregroundStyle(NativePalette.reminder)
        case .birthday:
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 20))
                .foregroundStyle(NativePalette.occasion)
        case .event:
            Image(systemName: item.eventType == .anniversary ? "heart.fill" : "star.fill")
                .font(.system(size: 20))
                .foregroundStyle(NativePalette.occasion)
        }
    }
}

// MARK: - New Task Sheet

struct NewTaskSheet: View {
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var l10n = L10n.shared

    @State private var title = ""
    @State private var date: Date
    @State private var hasTime = false
    @State private var time = Date()
    @State private var priority: Priority = .medium
    @State private var isReminder = false
    @State private var isSaving = false
    @State private var failed = false

    init(defaultDate: Date) {
        _date = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(l10n.titlePlaceholder, text: $title)
                    Picker("", selection: $isReminder) {
                        Text(l10n.taskLabel).tag(false)
                        Text(L10n.reminder).tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DatePicker(l10n.dateLabel, selection: $date, displayedComponents: .date)
                    Toggle(l10n.timeLabel, isOn: $hasTime.animation())
                    if hasTime {
                        DatePicker(l10n.timeLabel, selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }

                if !isReminder {
                    Section(l10n.priorityLabel) {
                        Picker(l10n.priorityLabel, selection: $priority) {
                            ForEach(Priority.allCases, id: \.self) { p in
                                Text(l10n.priorityName(p)).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if failed {
                    Text(l10n.saveFailed)
                        .foregroundStyle(NativePalette.high)
                }
            }
            .navigationTitle(l10n.newTask)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.add) { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .tint(NativePalette.accent)
        .environment(\.layoutDirection, l10n.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
    }

    private func save() {
        var input = CreateTaskInput(
            title: title.trimmingCharacters(in: .whitespaces),
            date: TasksView.isoDay.string(from: date)
        )
        if hasTime {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm"
            input.startTime = formatter.string(from: time)
        }
        input.taskType = isReminder ? .reminder : .task
        input.priority = priority
        input.userId = AuthManager.shared.currentUser?.id

        isSaving = true
        failed = false
        Task {
            do {
                _ = try await taskManager.createTask(input)
                dismiss()
            } catch {
                print("❌ Failed to create task: \(error)")
                failed = true
            }
            isSaving = false
        }
    }
}

// MARK: - Hashable (for navigationDestination)

extension TaskItem: Hashable {
    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    TasksView()
        .environmentObject(TaskManager.shared)
        .environmentObject(PeopleManager.shared)
        .environmentObject(EventManager.shared)
}
