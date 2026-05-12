import UIKit
import GoogleSignIn

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.makeKeyAndVisible()

        // Show a white placeholder immediately — prevents black flash while
        // async routing determines the correct initial screen.
        let placeholder = UIViewController()
        placeholder.view.backgroundColor = .white
        window.rootViewController = placeholder
        window.backgroundColor = .white

        // Determine root VC asynchronously — Supabase reads session from Keychain
        Task {
            // ── Fix: clear stale Keychain session on fresh install ──────────────
            // UserDefaults is wiped on uninstall; Keychain is not.
            // If the install marker is missing, this is a fresh install → force onboarding.
            let installKey = "consulto_install_marker"
            if !UserDefaults.standard.bool(forKey: installKey) {
                UserDefaults.standard.set(true, forKey: installKey)
                try? await AuthManager.shared.signOut() // clears Keychain + image cache + profile store
                let sb = UIStoryboard(name: "Onboarding-Login", bundle: nil)
                UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                    window.rootViewController = sb.instantiateInitialViewController()
                }
                return
            }
            // ────────────────────────────────────────────────────────────────────

            let isLoggedIn = await AuthManager.shared.isAuthenticated
            let destinationVC: UIViewController?

            if !isLoggedIn {
                let sb = UIStoryboard(name: "Onboarding-Login", bundle: nil)
                destinationVC = sb.instantiateInitialViewController()
            } else {
                let profile = try? await AuthManager.shared.fetchProfile()
                let hasProfile = (profile?.firstName ?? "").trimmingCharacters(in: .whitespaces).isEmpty == false

                if hasProfile {
                    let sb = UIStoryboard(name: "Main", bundle: nil)
                    destinationVC = sb.instantiateInitialViewController()
                    // Preload profile data + avatar in background so home screen is populated
                    Task.detached(priority: .background) {
                        await AuthManager.shared.preloadProfileData()
                    }
                } else {
                    let sb = UIStoryboard(name: "Onboarding-Login", bundle: nil)
                    if let profileVC = sb.instantiateViewController(withIdentifier: "ProfileViewController") as? ProfileViewController {
                        let nav = UINavigationController(rootViewController: profileVC)
                        nav.setNavigationBarHidden(true, animated: false)
                        destinationVC = nav
                    } else {
                        destinationVC = UIStoryboard(name: "Onboarding-Login", bundle: nil).instantiateInitialViewController()
                    }
                }
            }

            guard let finalVC = destinationVC else { return }

            // Cross-dissolve from white placeholder to real screen — no black flash
            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = finalVC
            }
        }
    }

    // MARK: - OAuth / deep-link callback (Google Sign-In, password reset)
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        // Let Google Sign-In handle its own callback first
        if GIDSignIn.sharedInstance.handle(url) { return }

        // Otherwise pass to Supabase (e.g. OAuth redirect, password reset)
        Task { await AuthManager.shared.handleOpenURL(url) }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
