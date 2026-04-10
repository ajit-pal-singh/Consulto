import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let existingVCs = viewControllers, existingVCs.count >= 3 else { return }

        // Wrap each existing storyboard VC into the new UITab API
        let recordsTab = UITab(
            title: existingVCs[0].tabBarItem.title ?? "Records",
            image: existingVCs[0].tabBarItem.image,
            identifier: "com.consulto.records"
        ) { _ in existingVCs[0] }

        let prepareTab = UITab(
            title: existingVCs[1].tabBarItem.title ?? "Prepare",
            image: existingVCs[1].tabBarItem.image,
            identifier: "com.consulto.prepare"
        ) { _ in existingVCs[1] }

        let vitalsTab = UITab(
            title: existingVCs[2].tabBarItem.title ?? "Vitals",
            image: existingVCs[2].tabBarItem.image,
            identifier: "com.consulto.vitals"
        ) { _ in existingVCs[2] }

        // UISearchTab — this is a SEPARATE tab that expands the search field
        // directly inside the tab bar (like Apple Health), not in the navigation bar.
        let searchVC = SearchViewController()
        let searchNavVC = UINavigationController(rootViewController: searchVC)

        let searchTab = UISearchTab(viewControllerProvider: { _ in
            return searchNavVC
        })

        self.tabs = [recordsTab, prepareTab, vitalsTab, searchTab]
    }
}
