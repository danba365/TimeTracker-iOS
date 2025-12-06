import SwiftUI

@main
struct TimeTrackerVoiceApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var taskManager = TaskManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                VoiceView()
                    .environmentObject(authManager)
                    .environmentObject(taskManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}

