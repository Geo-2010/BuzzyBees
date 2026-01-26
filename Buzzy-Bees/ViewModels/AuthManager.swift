//
//  AuthManager.swift
//  Rural-Activities
//

import Foundation

@Observable
class AuthManager {
    private let userDefaultsKey = "currentUser"
    private let userDirectoryKey = "userDirectory"

    var currentUser: User?
    private(set) var userDirectory: [String: String] = [:] // email -> displayName

    var isLoggedIn: Bool {
        currentUser != nil
    }

    init() {
        loadUserDirectory()
        loadUser()
    }

    /// Check if an email already exists in the user directory
    func isExistingUser(email: String) -> Bool {
        return userDirectory[email] != nil
    }

    /// Get the stored display name for an email, if it exists
    func storedDisplayName(for email: String) -> String? {
        return userDirectory[email]
    }

    func login(email: String, password: String, displayName: String) -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            return false
        }

        // For existing users, use their stored name; for new users, require a name
        let finalDisplayName: String
        if let existingName = userDirectory[email] {
            finalDisplayName = existingName
        } else {
            guard !displayName.isEmpty else {
                return false
            }
            finalDisplayName = displayName
        }

        let user = User(email: email, password: password, displayName: finalDisplayName)
        currentUser = user
        saveUser()

        // Add to user directory (updates if already exists)
        userDirectory[email] = finalDisplayName
        saveUserDirectory()

        return true
    }

    /// Returns the short display name for an email, or a privacy-masked email if not found
    func shortName(for email: String) -> String {
        if let displayName = userDirectory[email] {
            let parts = displayName.split(separator: " ")
            if parts.count >= 2 {
                let firstName = parts[0]
                let lastInitial = parts[1].prefix(1)
                return "\(firstName) \(lastInitial)."
            }
            return displayName
        }
        // If not in directory, show masked email
        if let atIndex = email.firstIndex(of: "@") {
            let prefix = email.prefix(2)
            return "\(prefix)***"
        }
        return "Anonymous"
    }

    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func saveUser() {
        guard let user = currentUser else { return }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        currentUser = user

        // Ensure current user is in directory
        if let user = currentUser {
            userDirectory[user.email] = user.displayName
            saveUserDirectory()
        }
    }

    private func saveUserDirectory() {
        if let encoded = try? JSONEncoder().encode(userDirectory) {
            UserDefaults.standard.set(encoded, forKey: userDirectoryKey)
        }
    }

    private func loadUserDirectory() {
        guard let data = UserDefaults.standard.data(forKey: userDirectoryKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        userDirectory = decoded
    }
}
