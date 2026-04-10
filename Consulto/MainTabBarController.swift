import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let existingVCs = viewControllers, existingVCs.count >= 3 else { return }

        // Wrap each storyboard VC into the UITab API.
        // Title and image are read from each VC's tabBarItem (set in their init(coder:)).
        let homeTab = UITab(
            title: existingVCs[0].tabBarItem.title ?? "Home",
            image: existingVCs[0].tabBarItem.image,
            identifier: "com.consulto.home"
        ) { _ in existingVCs[0] }

        let recordsTab = UITab(
            title: existingVCs[1].tabBarItem.title ?? "Records",
            image: existingVCs[1].tabBarItem.image,
            identifier: "com.consulto.records"
        ) { _ in existingVCs[1] }

        let visitsTab = UITab(
            title: existingVCs[2].tabBarItem.title ?? "Visits",
            image: existingVCs[2].tabBarItem.image,
            identifier: "com.consulto.visits"
        ) { _ in existingVCs[2] }

        // UISearchTab expands inline in the tab bar (like Apple Health).
        let searchVC = SearchViewController()
        let searchNavVC = UINavigationController(rootViewController: searchVC)
        let searchTab = UISearchTab { _ in searchNavVC }

        self.tabs = [homeTab, recordsTab, visitsTab, searchTab]
    }
}

