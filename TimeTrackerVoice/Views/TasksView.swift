import SwiftUI

/// Weekly tasks view displaying tasks organized by day
struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    
    private let calendar = Calendar.current
    
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
                
                // Week selector
                weekSelectorView
                
                // Tasks list
                if taskManager.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    tasksListView
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Tasks")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(selectedDate.formatted(.dateTime.month().year()))
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Spacer()
            
            Button(action: { selectedDate = Date() }) {
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "a78bfa"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "a78bfa").opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Week Selector
    
    private var weekSelectorView: some View {
        let weekDays = getWeekDays(for: selectedDate)
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.self) { date in
                    DayButton(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        hasTask: hasTasksOnDate(date)
                    ) {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Tasks List
    
    private var tasksListView: some View {
        let dayTasks = getTasksForSelectedDate()
        
        return ScrollView {
            LazyVStack(spacing: 12) {
                if dayTasks.isEmpty {
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
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "475569"))
            
            Text("No tasks for this day")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(hex: "64748b"))
            
            Text("Use the voice or chat to add tasks")
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
        return taskManager.tasks.contains { $0.date == dateStr }
    }
    
    private func getTasksForSelectedDate() -> [TaskItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        return taskManager.tasks
            .filter { $0.date == dateStr }
            .sorted { ($0.startTime ?? "") < ($1.startTime ?? "") }
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
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color(hex: "64748b"))
                
                Text(dayNumber)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color(hex: "94a3b8"))
                
                if hasTask {
                    Circle()
                        .fill(isSelected ? Color.white : Color(hex: "a78bfa"))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
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
                            Text(startTime)
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
}

#Preview {
    TasksView()
        .environmentObject(TaskManager.shared)
}

