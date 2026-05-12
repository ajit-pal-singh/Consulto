import UIKit
import UserNotifications
import GoogleSignIn

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // MARK: - Supabase (supabase-swift auto-initialises via `supabase` global in AuthManager)
        // Nothing extra needed — the client is lazy-loaded.

        // MARK: - Google Sign-In configuration
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: GoogleSignInConfig.clientID)

        // MARK: - Local notifications
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        ReminderNotificationScheduler.shared.requestAuthorizationIfNeeded()
        ReminderNotificationScheduler.shared.refreshAll()

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
