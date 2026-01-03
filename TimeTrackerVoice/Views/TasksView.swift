import SwiftUI

/// Weekly tasks view displaying tasks organized by day
struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var peopleManager: PeopleManager
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @GestureState private var dragOffset: CGFloat = 0
    
    private let calendar = Calendar.current
    
    /// Get people with birthdays on the selected date
    private var birthdaysOnSelectedDate: [Person] {
        let day = calendar.component(.day, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        return peopleManager.people.filter { person in
            guard let birthdayStr = person.birthday else { return false }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let birthdayDate = formatter.date(from: birthdayStr) else { return false }
            
            let birthdayDay = calendar.component(.day, from: birthdayDate)
            let birthdayMonth = calendar.component(.month, from: birthdayDate)
            
            return birthdayDay == day && birthdayMonth == month
        }
    }
    
    /// Check if there's a birthday on a given date
    private func hasBirthdayOnDate(_ date: Date) -> Bool {
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        
        return peopleManager.people.contains { person in
            guard let birthdayStr = person.birthday else { return false }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let birthdayDate = formatter.date(from: birthdayStr) else { return false }
            
            let birthdayDay = calendar.component(.day, from: birthdayDate)
            let birthdayMonth = calendar.component(.month, from: birthdayDate)
            
            return birthdayDay == day && birthdayMonth == month
        }
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
                
                // Week selector (swipeable)
                weekSelectorView
                
                // Tasks list with swipe gesture
                if taskManager.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    tasksListView
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    state = value.translation.width
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    if value.translation.width > threshold {
                                        // Swipe right - go to previous day
                                        withAnimation {
                                            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                        }
                                    } else if value.translation.width < -threshold {
                                        // Swipe left - go to next day
                                        withAnimation {
                                            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                        }
                                    }
                                }
                        )
                }
            }
        }
        .onAppear {
            Task {
                await taskManager.fetchTasks()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Offline indicator
            if taskManager.isOffline {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                    Text(L10n.offlineMode)
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(hex: "f59e0b"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "f59e0b").opacity(0.15))
                .cornerRadius(8)
            }
            
            HStack {
                // Previous day button
                Button(action: {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "a78bfa"))
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text(formattedDayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text(formattedFullDate)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "94a3b8"))
                    
                    // Last sync indicator
                    if let lastSync = taskManager.lastSyncDate {
                        Text("\(L10n.updated): \(formatLastSync(lastSync))")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "64748b"))
                    }
                }
                
                Spacer()
                
                // Next day button
                Button(action: {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "a78bfa"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .topTrailing) {
            // Today button
            if !calendar.isDateInToday(selectedDate) {
                Button(action: { 
                    withAnimation {
                        selectedDate = Date()
                    }
                }) {
                    Text(L10n.today)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "a78bfa"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "a78bfa").opacity(0.2))
                        .cornerRadius(6)
                }
                .padding(.top, 12)
                .padding(.trailing, 20)
            }
        }
    }
    
    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "he")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var formattedDayName: String {
        if calendar.isDateInToday(selectedDate) {
            return L10n.today
        } else if calendar.isDateInYesterday(selectedDate) {
            return L10n.yesterday
        } else if calendar.isDateInTomorrow(selectedDate) {
            return L10n.tomorrow
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "he")
            formatter.dateFormat = "EEEE"
            return formatter.string(from: selectedDate)
        }
    }
    
    private var formattedFullDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    // MARK: - Week Selector (Infinite Scroll)
    
    private var weekSelectorView: some View {
        // Show 3 weeks: previous, current, next (centered on selected date)
        let allDays = getExtendedDays(for: selectedDate, range: 21) // 3 weeks
        
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allDays, id: \.self) { date in
                        DayButton(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasTask: hasTasksOnDate(date),
                            hasBirthday: hasBirthdayOnDate(date)
                        ) {
                            withAnimation {
                                selectedDate = date
                            }
                        }
                        .id(date)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                // Scroll to selected date
                proxy.scrollTo(selectedDate, anchor: .center)
            }
            .onChange(of: selectedDate) { _, newDate in
                withAnimation {
                    proxy.scrollTo(newDate, anchor: .center)
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    private func getExtendedDays(for date: Date, range: Int) -> [Date] {
        var days: [Date] = []
        let halfRange = range / 2
        
        for i in -halfRange...halfRange {
            if let day = calendar.date(byAdding: .day, value: i, to: date) {
                days.append(day)
            }
        }
        return days
    }
    
    // MARK: - Tasks List (with Pull-to-Refresh)
    
    private var tasksListView: some View {
        let dayTasks = getTasksForSelectedDate()
        
        return ScrollView {
            LazyVStack(spacing: 12) {
                // Pull to refresh hint
                if taskManager.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "a78bfa")))
                        Text(L10n.refreshing)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "94a3b8"))
                    }
                    .padding(.vertical, 8)
                }
                
                // 🎂 Birthdays Section
                if !birthdaysOnSelectedDate.isEmpty {
                    ForEach(birthdaysOnSelectedDate, id: \.id) { person in
                        BirthdayRowView(person: person)
                    }
                }
                
                if dayTasks.isEmpty && birthdaysOnSelectedDate.isEmpty {
                    emptyStateView
                } else {
                    ForEach(dayTasks, id: \.id) { task in
                        TaskRowView(task: task) {
                            toggleTaskStatus(task)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for tab bar
        }
        .refreshable {
            // Pull-to-refresh action
            await refreshData()
        }
    }
    
    // MARK: - Refresh Data
    
    private func refreshData() async {
        print("🔄 Pull to refresh triggered")
        await taskManager.fetchTasks()
        await taskManager.fetchCategories()
        await PeopleManager.shared.fetchPeople()
        print("✅ Refresh complete")
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "475569"))
            
            Text(L10n.noTasksTitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "64748b"))
            
            Text(L10n.noTasksSubtitle)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "475569"))
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
    private func getWeekDays(for date: Date) -> [Date] {
        var days: [Date] = []
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                days.append(day)
            }
        }
        return days
    }
    
    private func hasTasksOnDate(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        let tasksForDate = taskManager.tasks.filter { $0.date == dateStr }
        
        // Count visible tasks (using same filtering logic)
        let visibleTasks = tasksForDate.filter { task in
            // Hide tasks without parentTaskId if there's a duplicate with parentTaskId
            if task.parentTaskId == nil {
                let hasDuplicateInstance = tasksForDate.contains { otherTask in
                    otherTask.id != task.id &&
                    otherTask.title == task.title &&
                    otherTask.parentTaskId != nil
                }
                if hasDuplicateInstance { return false }
            }
            
            // Hide recurring parents if instance exists
            if task.isRecurring && task.parentTaskId == nil {
                let hasInstance = taskManager.tasks.contains { otherTask in
                    otherTask.parentTaskId == task.id && otherTask.date == dateStr
                }
                if hasInstance { return false }
            }
            
            return true
        }
        
        return !visibleTasks.isEmpty
    }
    
    private func getTasksForSelectedDate() -> [TaskItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        
        // Get all tasks for this date
        let tasksForDate = taskManager.tasks.filter { $0.date == dateStr }
        print("🔍 [TasksView] Date: \(dateStr), Found \(tasksForDate.count) tasks")
        
        let filtered = tasksForDate
            .filter { task in
                print("   🔍 Checking: '\(task.title)' | isRecurring=\(task.isRecurring) | parentTaskId=\(task.parentTaskId ?? "nil")")
                
                // Strategy: If this task has NO parentTaskId, check if there's
                // another task with the SAME title that HAS a parentTaskId.
                // If so, hide this one (show the instance instead of the parent)
                if task.parentTaskId == nil {
                    let hasDuplicateInstance = tasksForDate.contains { otherTask in
                        otherTask.id != task.id &&
                        otherTask.title == task.title &&
                        otherTask.parentTaskId != nil
                    }
                    
                    if hasDuplicateInstance {
                        print("   🔍 -> HIDDEN: Found instance with same title, hiding parent")
                        return false
                    }
                }
                
                // Also check original logic for recurring parents
                if task.isRecurring && task.parentTaskId == nil {
                    let hasInstance = taskManager.tasks.contains { otherTask in
                        otherTask.parentTaskId == task.id && otherTask.date == dateStr
                    }
                    if hasInstance {
                        print("   🔍 -> HIDDEN: Recurring parent with instance")
                        return false
                    }
                }
                
                print("   🔍 -> Showing task")
                return true
            }
            .sorted { ($0.startTime ?? "") < ($1.startTime ?? "") }
        
        print("🔍 [TasksView] Filtered to \(filtered.count) visible tasks")
        return filtered
    }
    
    private func toggleTaskStatus(_ task: TaskItem) {
        Task {
            let newStatus: TaskStatus = task.status == .done ? .todo : .done
            let input = UpdateTaskInput(status: newStatus)
            try? await taskManager.updateTask(id: task.id, input: input)
        }
    }
}

// MARK: - Day Button

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let hasTask: Bool
    let hasBirthday: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color(hex: "64748b"))
                
                ZStack {
                    Text(dayNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isSelected ? .white : Color(hex: "94a3b8"))
                    
                    // Birthday indicator (cake emoji on top-right)
                    if hasBirthday {
                        Text("🎂")
                            .font(.system(size: 10))
                            .offset(x: 12, y: -8)
                    }
                }
                
                // Dots for task and birthday
                HStack(spacing: 3) {
                    if hasTask {
                        Circle()
                            .fill(isSelected ? Color.white : Color(hex: "a78bfa"))
                            .frame(width: 5, height: 5)
                    }
                    if hasBirthday && !hasTask {
                        Circle()
                            .fill(isSelected ? Color.white : Color(hex: "f472b6"))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(width: 44, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "7c3aed") : Color.white.opacity(0.05))
            )
        }
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status button
            Button(action: onToggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.status == .done ? Color(hex: "10b981") : Color(hex: "475569"))
            }
            
            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(task.status == .done ? Color(hex: "64748b") : .white)
                    .strikethrough(task.status == .done)
                
                HStack(spacing: 8) {
                    if let startTime = task.startTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            // Format time to show only HH:MM (remove seconds)
                            Text(formatTimeWithoutSeconds(startTime))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(hex: "64748b"))
                    }
                    
                    priorityBadge
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var priorityBadge: some View {
        let color: Color = {
            switch task.priority {
            case .high: return Color(hex: "ef4444")
            case .medium: return Color(hex: "f59e0b")
            case .low: return Color(hex: "10b981")
            }
        }()
        
        return Text(task.priority.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }
    
    // MARK: - Helpers
    
    /// Formats time string from "HH:MM:SS" to "HH:MM"
    private func formatTimeWithoutSeconds(_ time: String) -> String {
        let components = time.split(separator: ":")
        if components.count >= 2 {
            return "\(components[0]):\(components[1])"
        }
        return time
    }
}

// MARK: - Birthday Row View

struct BirthdayRowView: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 12) {
            // Birthday icon
            ZStack {
                Circle()
                    .fill(Color(hex: "f472b6").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text("🎂")
                    .font(.system(size: 22))
            }
            
            // Person info
            VStack(alignment: .leading, spacing: 4) {
                Text(birthdayTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    if let relationship = person.relationshipDetail ?? relationshipTypeLabel {
                        Text(relationship)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "f472b6"))
                    }
                    
                    if let age = person.age {
                        Text(L10n.shared.currentLanguage == .hebrew ? "מלאו \(age + 1)" : "Turning \(age + 1)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "94a3b8"))
                    }
                }
            }
            
            Spacer()
            
            // Celebration icon
            Text("🎉")
                .font(.system(size: 20))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "f472b6").opacity(0.15), Color(hex: "a855f7").opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "f472b6").opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var birthdayTitle: String {
        let isHebrew = L10n.shared.currentLanguage == .hebrew
        let name = person.fullName
        return isHebrew ? "יום הולדת ל\(name)!" : "\(name)'s Birthday!"
    }
    
    private var relationshipTypeLabel: String? {
        switch person.relationshipType {
        case .family:
            return L10n.shared.currentLanguage == .hebrew ? "משפחה" : "Family"
        case .friend:
            return L10n.shared.currentLanguage == .hebrew ? "חבר" : "Friend"
        case .colleague:
            return L10n.shared.currentLanguage == .hebrew ? "עמית" : "Colleague"
        case .other:
            return nil
        }
    }
}

#Preview {
    TasksView()
        .environmentObject(TaskManager.shared)
        .environmentObject(PeopleManager.shared)
}

