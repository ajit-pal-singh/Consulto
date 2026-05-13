// AuthManager.swift
// Consulto — Supabase Auth singleton (no PostHog)
//
// Handles: email/password sign-up & sign-in, OTP verification,
//          Google Sign-In, profile CRUD via Supabase Postgres + Storage,
//          and password updates.

import UIKit
import Supabase
import GoogleSignIn

// MARK: - Supabase client (shared singleton)
let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: .init(
        auth: .init(
            emitLocalSessionAsInitialSession: true
        )
    )
)

// MARK: - Decodable profile row (matches public.profiles table)
struct SupabaseProfile: Codable {
    let id: UUID
    var firstName: String?
    var lastName: String?
    var gender: String?
    var dateOfBirth: String?   // stored as ISO-8601 date string "YYYY-MM-DD"
    var avatarUrl: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName   = "first_name"
        case lastName    = "last_name"
        case gender
        case dateOfBirth = "date_of_birth"
        case avatarUrl   = "avatar_url"
        case createdAt   = "created_at"
    }
}

// MARK: - AuthManager
@MainActor
final class AuthManager {

    static let shared = AuthManager()
    private init() {}

    // MARK: - Public state

    /// Returns the currently authenticated Supabase user, or nil.
    var currentUser: User? {
        get async {
            try? await supabase.auth.session.user
        }
    }

    /// True when a valid Supabase session exists in the Keychain.
    var isAuthenticated: Bool {
        get async {
            (try? await supabase.auth.session) != nil
        }
    }

    // MARK: - Email / Password

    /// Sign up a new user. Supabase sends a 6-digit OTP to `email`.
    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(
            email: email,
            password: password,
            redirectTo: URL(string: "consulto://oauth-callback")
        )
    }

    /// Verify the OTP the user received after sign-up (type: .signup).
    func verifyOTP(email: String, token: String) async throws {
        try await supabase.auth.verifyOTP(
            email: email,
            token: token,
            type: .signup   // .signup for post-sign-up email confirmation
        )
    }

    /// Resend the sign-up confirmation OTP to `email`.
    func resendOTP(email: String) async throws {
        try await supabase.auth.resend(
            email: email,
            type: .signup
        )
    }

    /// Sign in an existing user with email + password.
    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(
            email: email,
            password: password
        )
    }

    /// Sign out and clear ALL local state: Supabase session, image cache, profile store.
    func signOut() async throws {
        // Clear on-device profile image so next login fetches fresh
        ProfileImageManager.shared.clearImage()

        // Reset local profile store to defaults
        UserProfileStore.shared.reset()

        // Sign out from Supabase (clears Keychain session)
        try await supabase.auth.signOut()
    }

    // MARK: - Google Sign-In

    /// Launches the Google sign-in sheet and exchanges the token with Supabase.
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        // 1. Google sign-in (native account picker)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleTokenMissing
            }
            let accessToken = result.user.accessToken.tokenString

            // 2. Exchange with Supabase
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
        } catch {
            print("[AuthManager] Google sign-in error:", error)
            throw error
        }
    }

    // MARK: - Profile

    /// Fetch this user's row from public.profiles.
    func fetchProfile() async throws -> SupabaseProfile {
        guard let user = try? await supabase.auth.session.user else {
            throw AuthError.notAuthenticated
        }
        let profile: SupabaseProfile = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()
            .value
        return profile
    }

    /// Save (upsert) profile data and optionally upload a new avatar.
    /// - Uploads avatar to `avatars/{uid}/avatar.jpg` in Supabase Storage.
    /// - Saves avatar URL in the profiles table.
    /// - Caches the image on-device via ProfileImageManager.
    func saveProfile(_ profile: SupabaseProfile, avatarImage: UIImage? = nil) async throws {
        guard let user = try? await supabase.auth.session.user else {
            throw AuthError.notAuthenticated
        }

        var updatedProfile = profile

        // 1. Upload avatar if provided (non-fatal — storage misconfiguration won't block profile save)
        if let image = avatarImage,
           let jpegData = image.jpegData(compressionQuality: 0.8) {
            do {
                let path = "\(user.id.uuidString)/avatar.jpg"
                try await supabase.storage
                    .from("avatars")
                    .upload(
                        path,
                        data: jpegData,
                        options: .init(contentType: "image/jpeg", upsert: true)
                    )
                // Build a signed URL (valid 10 years — effectively permanent for private bucket)
                let signedURL = try await supabase.storage
                    .from("avatars")
                    .createSignedURL(path: path, expiresIn: 315_360_000)
                updatedProfile.avatarUrl = signedURL.absoluteString
            } catch {
                print("[AuthManager] Avatar upload failed (non-fatal):", error.localizedDescription)
            }
            // Always cache on-device regardless of upload success
            ProfileImageManager.shared.saveImage(image)
        }

        // 2. Upsert to profiles table
        try await supabase
            .from("profiles")
            .upsert(updatedProfile)
            .execute()
    }

    // MARK: - Password

    /// Update the authenticated user's password.
    func updatePassword(to newPassword: String) async throws {
        try await supabase.auth.update(user: .init(password: newPassword))
    }

    /// Verifies `currentPassword` by re-signing in, then updates to `newPassword`.
    /// Throws if the current password is wrong or the user is not authenticated.
    func verifyAndUpdatePassword(current currentPassword: String, new newPassword: String) async throws {
        // 1. Get the signed-in user's email
        guard let user = try? await supabase.auth.session.user,
              let email = user.email, !email.isEmpty else {
            throw AuthError.notAuthenticated
        }
        // 2. Re-authenticate — this will throw if the password is wrong
        try await supabase.auth.signIn(email: email, password: currentPassword)
        // 3. Current password verified — now set the new one
        try await supabase.auth.update(user: .init(password: newPassword))
    }

    /// Sends a password-reset OTP to the given email (forgot password flow).
    func sendPasswordResetOTP(to email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    /// Verifies the recovery OTP sent via resetPasswordForEmail.
    /// NOTE: Uses type .recovery — distinct from the .signup OTP used in sign-up flow.
    func verifyPasswordResetOTP(email: String, token: String) async throws {
        try await supabase.auth.verifyOTP(
            email: email,
            token: token,
            type: .recovery
        )
    }

    /// Updates the password after the reset OTP has been verified.
    /// Must be called while a valid Supabase session exists (i.e. after OTP verification succeeds).
    func updatePasswordForReset(to newPassword: String) async throws {
        try await supabase.auth.update(user: .init(password: newPassword))
    }

    // MARK: - Profile preload

    /// Fetches the remote profile and syncs it into UserProfileStore + avatar cache.
    /// Call this immediately after a successful sign-in so all screens have fresh data.
    func preloadProfileData() async {
        guard let profile = try? await fetchProfile() else { return }

        UserProfileStore.shared.update { local in
            if let fn = profile.firstName, !fn.isEmpty { local.firstName = fn }
            if let ln = profile.lastName,  !ln.isEmpty { local.lastName  = ln }
            if let g  = profile.gender,    !g.isEmpty  { local.gender    = Gender(displayName: g) }
            if let dobStr = profile.dateOfBirth {
                let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                if let dob = fmt.date(from: dobStr) { local.dateOfBirth = dob }
            }
        }
        if let email = try? await supabase.auth.session.user.email {
            UserProfileStore.shared.update { $0.email = email }
        }
        await restoreAvatarIfNeeded(from: profile.avatarUrl)
    }

    // MARK: - Avatar restore

    /// Downloads the avatar from `avatarURLString` and caches it on-device
    /// if there is no local copy already. Safe to call on every app launch.
    func restoreAvatarIfNeeded(from avatarURLString: String?) async {
        // Skip if already cached locally
        guard ProfileImageManager.shared.fetchImage() == nil else { return }
        guard let urlString = avatarURLString,
              let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                ProfileImageManager.shared.saveImage(image)
                print("[AuthManager] Avatar restored from Supabase.")
                // Notify observers so UI refreshes
                NotificationCenter.default.post(name: NSNotification.Name("ProfileImageUpdated"), object: nil)
            }
        } catch {
            print("[AuthManager] Avatar restore failed (non-fatal):", error.localizedDescription)
        }
    }

    // MARK: - Deep link / OAuth callback

    /// Call this from SceneDelegate when the app is opened via a `consulto://` URL.
    func handleOpenURL(_ url: URL) async {
        try? await supabase.auth.session(from: url)
    }
}

// MARK: - Custom errors
enum AuthError: LocalizedError {
    case notAuthenticated
    case googleTokenMissing

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "You are not signed in. Please log in and try again."
        case .googleTokenMissing: return "Google Sign-In did not return an ID token."
        }
    }
}
