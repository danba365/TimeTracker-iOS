import SwiftUI

/// Detail view for displaying full task/reminder information
struct TaskDetailView: View {
    let task: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) private var dismiss
    
    private let isHebrew = L10n.shared.currentLanguage == .hebrew
    
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
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with status
                    headerSection
                    
                    // Quick Actions
                    actionsSection
                    
                    // Details Section
                    detailsSection
                    
                    // Description Section
                    if let description = task.description, !description.isEmpty {
                        descriptionSection(description)
                    }
                    
                    // Tags Section
                    if !task.tags.isEmpty {
                        tagsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "1a1a2e"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            
            // Title
            Text(task.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Type & Status badges
            HStack(spacing: 12) {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: task.taskType == .reminder ? "bell.fill" : "checkmark.square")
                        .font(.system(size: 12))
                    Text(task.taskType == .reminder ? (isHebrew ? "תזכורת" : "Reminder") : (isHebrew ? "משימה" : "Task"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(task.taskType == .reminder ? Color(hex: "06b6d4") : Color(hex: "a78bfa"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((task.taskType == .reminder ? Color(hex: "06b6d4") : Color(hex: "a78bfa")).opacity(0.15))
                .cornerRadius(12)
                
                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "clock")
                        .font(.system(size: 12))
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 16) {
            // Toggle Status Button
            TaskActionButton(
                icon: task.status == .done ? "arrow.uturn.backward" : "checkmark",
                label: task.status == .done ? (isHebrew ? "לא בוצע" : "Undo") : (isHebrew ? "בוצע" : "Done"),
                color: task.status == .done ? Color(hex: "f59e0b") : Color(hex: "10b981")
            ) {
                toggleStatus()
            }
            
            // Delete Button
            TaskActionButton(
                icon: "trash",
                label: isHebrew ? "מחק" : "Delete",
                color: Color(hex: "ef4444")
            ) {
                deleteTask()
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Date
            TaskDetailRow(
                icon: "calendar",
                label: isHebrew ? "תאריך" : "Date",
                value: formatDate(task.date),
                iconColor: Color(hex: "60a5fa")
            )
            
            Divider().background(Color.white.opacity(0.1))
            
            // Time
            if let startTime = task.startTime {
                TaskDetailRow(
                    icon: "clock",
                    label: isHebrew ? "שעה" : "Time",
                    value: formatTime(startTime, endTime: task.endTime),
                    iconColor: Color(hex: "22d3ee")
                )
                
                Divider().background(Color.white.opacity(0.1))
            }
            
            // Priority (only for tasks)
            if task.taskType == .task {
                TaskDetailRow(
                    icon: "flag.fill",
                    label: isHebrew ? "עדיפות" : "Priority",
                    value: priorityText,
                    iconColor: priorityColor
                )
                
                if task.isRecurring || task.parentTaskId != nil {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
            
            // Recurring indicator
            if task.isRecurring || task.parentTaskId != nil {
                TaskDetailRow(
                    icon: "repeat",
                    label: isHebrew ? "חוזר" : "Recurring",
                    value: isHebrew ? "כן" : "Yes",
                    iconColor: Color(hex: "8b5cf6")
                )
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Description Section
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(Color(hex: "fbbf24"))
                Text(isHebrew ? "תיאור" : "Description")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            Text(description)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: isHebrew ? .trailing : .leading)
                .multilineTextAlignment(isHebrew ? .trailing : .leading)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(Color(hex: "a78bfa"))
                Text(isHebrew ? "תגיות" : "Tags")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
            
            FlowLayout(spacing: 8) {
                ForEach(task.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "a78bfa"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "a78bfa").opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private var statusIcon: String {
        switch task.status {
        case .done: return "checkmark.circle.fill"
        case .inProgress: return "play.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        case .todo: return task.taskType == .reminder ? "bell.fill" : "circle"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .done: return Color(hex: "10b981")
        case .inProgress: return Color(hex: "60a5fa")
        case .missed: return Color(hex: "ef4444")
        case .todo: return task.taskType == .reminder ? Color(hex: "06b6d4") : Color(hex: "64748b")
        }
    }
    
    private var statusText: String {
        switch task.status {
        case .done: return isHebrew ? "הושלם" : "Done"
        case .inProgress: return isHebrew ? "בתהליך" : "In Progress"
        case .missed: return isHebrew ? "פספסת" : "Missed"
        case .todo: return isHebrew ? "לביצוע" : "To Do"
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .high: return isHebrew ? "גבוהה" : "High"
        case .medium: return isHebrew ? "בינונית" : "Medium"
        case .low: return isHebrew ? "נמוכה" : "Low"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .high: return Color(hex: "ef4444")
        case .medium: return Color(hex: "f59e0b")
        case .low: return Color(hex: "10b981")
        }
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        
        formatter.dateFormat = isHebrew ? "EEEE, d בMMMM yyyy" : "EEEE, MMMM d, yyyy"
        formatter.locale = Locale(identifier: isHebrew ? "he_IL" : "en_US")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ startTime: String, endTime: String?) -> String {
        let start = formatTimeString(startTime)
        if let end = endTime {
            return "\(start) - \(formatTimeString(end))"
        }
        return start
    }
    
    private func formatTimeString(_ time: String) -> String {
        let components = time.split(separator: ":")
        if components.count >= 2 {
            return "\(components[0]):\(components[1])"
        }
        return time
    }
    
    private func toggleStatus() {
        Task {
            let newStatus: TaskStatus = task.status == .done ? .todo : .done
            let input = UpdateTaskInput(status: newStatus)
            try? await taskManager.updateTask(id: task.id, input: input)
            dismiss()
        }
    }
    
    private func deleteTask() {
        Task {
            try? await taskManager.deleteTask(id: task.id)
            dismiss()
        }
    }
}

// MARK: - Task Action Button

struct TaskActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "94a3b8"))
            }
        }
    }
}

// MARK: - Task Detail Row

struct TaskDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "64748b"))
                
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(task: TaskItem(
            id: "1",
            title: "Complete project documentation",
            description: "Write comprehensive documentation for the new feature including API specs and user guides.",
            date: "2026-01-13",
            startTime: "09:00:00",
            endTime: "12:00:00",
            priority: .high,
            status: .todo,
            taskType: .task,
            categoryId: nil,
            tags: ["Work", "Documentation", "Urgent"],
            isRecurring: false,
            parentTaskId: nil,
            createdAt: "2026-01-01",
            updatedAt: "2026-01-01"
        ))
        .environmentObject(TaskManager.shared)
    }
}
