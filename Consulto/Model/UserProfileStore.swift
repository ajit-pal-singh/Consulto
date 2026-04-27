import Foundation

extension Notification.Name {
    static let userProfileDidChange = Notification.Name("UserProfileDidChange")
}

final class UserProfileStore {
    static let shared = UserProfileStore()

    private let fileName = "user_profile.json"
    private(set) var current: UserProfile

    private init() {
        current = Self.loadProfile()
    }

    func save(_ profile: UserProfile) {
        current = profile
        persist(profile)
        NotificationCenter.default.post(name: .userProfileDidChange, object: profile)
    }

    func update(_ changes: (inout UserProfile) -> Void) {
        var updatedProfile = current
        changes(&updatedProfile)
        save(updatedProfile)
    }

    private static func loadProfile() -> UserProfile {
        let url = profileFileURL(fileName: "user_profile.json")
        guard let data = try? Data(contentsOf: url),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile(
                id: UUID(),
                firstName: "Demo",
                lastName: "User",
                dateOfBirth: Date(),
                gender: .preferNotToSay,
                email: "demouser@gmail.com",
                createdAt: Date()
            )
        }
        return profile
    }

    private func persist(_ profile: UserProfile) {
        let url = Self.profileFileURL(fileName: fileName)
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private static func profileFileURL(fileName: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
