import SwiftUI

@main
struct CastNowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Enable idle-timer stay on during broadcast handled by broadcast screen.
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Broadcast extension keeps streaming while backgrounded; nothing needed.
    }
}