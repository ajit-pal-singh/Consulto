
import UIKit

class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
         super.viewDidLoad()
         self.delegate = self
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
         let index = viewControllers?.firstIndex(of: viewController)
         
         // Assuming "Search" is the 4th tab (index 3)
         if index == 3 {
             // Broadcast to ConsultViewController to expand the search bar
             NotificationCenter.default.post(name: NSNotification.Name("ExpandSearchTabTapped"), object: nil)
             
             // Return false so we stay on the current screen!
             return false
         }
         return true
    }
}
