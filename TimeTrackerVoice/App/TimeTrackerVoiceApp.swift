import SwiftUI
import GoogleSignIn

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
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
    
    init() {
        // Configure Google Sign-In on app launch
        if !Config.googleClientID.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
        }
    }
}

// MARK: - App Delegate for handling URL callbacks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
