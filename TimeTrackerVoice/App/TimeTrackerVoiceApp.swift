import SwiftUI
import GoogleSignIn

@main
struct TimeTrackerVoiceApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var peopleManager = PeopleManager.shared
    @StateObject private var eventManager = EventManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(authManager)
                    .environmentObject(taskManager)
                    .environmentObject(peopleManager)
                    .environmentObject(eventManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }
    
    init() {
        // Configure Google Sign-In on app launch
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: Config.googleClientID)
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
