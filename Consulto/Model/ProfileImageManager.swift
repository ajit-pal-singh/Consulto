import Foundation
import UIKit

class ProfileImageManager {
    static let shared = ProfileImageManager()
    private let fileName = "userProfileImage.jpg"
    
    #if canImport(UIKit)
    func saveImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        try? data.write(to: url)
        NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
    }
    
    func fetchImage() -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
    #endif
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
