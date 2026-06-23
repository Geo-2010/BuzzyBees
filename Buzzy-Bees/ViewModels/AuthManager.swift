//
//  AuthManager.swift
//  Buzzy-Bees
//

import Foundation

@Observable
class AuthManager {
    private let userDefaultsKey = "currentUser"
    private let userDirectoryKey = "userDirectory"

    var currentUser: User?
    private(set) var userDirectory: [String: String] = [:]  // email -> displayName
    var isLoading = false
    var authError: String?

    var isLoggedIn: Bool { currentUser != nil }

    init() {
        loadUserDirectory()
        loadUser()
        // Restore JWT token into APIService on launch
        if let token = KeychainService.loadToken() {
            APIService.shared.setAuthToken(token)
        }
        // Listen for token-expired notifications (e.g. 401 from any API call)
        NotificationCenter.default.addObserver(
            forName: .authTokenExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }

    // MARK: - User lookup helpers

    func isExistingUser(email: String) -> Bool {
        userDirectory[email.lowercased()] != nil
    }

    func storedDisplayName(for email: String) -> String? {
        userDirectory[email.lowercased()]
    }

    func shortName(for email: String) -> String {
        if let displayName = userDirectory[email.lowercased()] {
            let parts = displayName.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0]) \(parts[1].prefix(1))."
            }
            return displayName
        }
        if email.contains("@") {
            return "\(email.prefix(2))***"
        }
        return "Anonymous"
    }

    // MARK: - Login / Registration

    /// Attempts server auth first, falls back to local Keychain auth if unreachable.
    func login(email: String, password: String, displayName: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard !email.isEmpty, !password.isEmpty else {
            authError = "Email and password are required"
            return false
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isExisting = userDirectory[trimmedEmail] != nil

        if isExisting {
            // Existing user — try server login, fall back to local if unreachable
            do {
                let response = try await APIService.shared.login(email: trimmedEmail, password: password)
                return completeLogin(email: trimmedEmail, password: password, displayName: response.displayName, token: response.token)
            } catch APIServiceError.serverError(let msg) {
                authError = msg
                return false
            } catch {
                // Server unreachable — fall back to local Keychain auth
                return localLogin(email: trimmedEmail, password: password)
            }
        } else {
            // New user — require display name, register on server
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                authError = "Display name is required for new accounts"
                return false
            }
            do {
                let response = try await APIService.shared.register(
                    email: trimmedEmail,
                    password: password,
                    displayName: trimmedName
                )
                return completeLogin(email: trimmedEmail, password: password, displayName: response.displayName, token: response.token)
            } catch APIServiceError.serverError(let msg) {
                authError = msg
                return false
            } catch {
                authError = "Registration failed. Please check your connection and try again."
                return false
            }
        }
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteToken()
        if let email = currentUser?.email {
            KeychainService.delete(for: email)
        }
        APIService.shared.setAuthToken(nil)
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    // MARK: - Profile Update

    /// Update the current user's display name on the server and locally.
    func updateDisplayName(to newName: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            authError = "Display name must be at least 2 characters"
            return false
        }

        do {
            let updatedName = try await APIService.shared.updateProfile(displayName: trimmed)
            guard var user = currentUser else { return false }
            user = User(email: user.email, displayName: updatedName)
            currentUser = user
            userDirectory[user.email] = updatedName
            saveUser()
            saveUserDirectory()
            return true
        } catch APIServiceError.serverError(let msg) {
            authError = msg
            return false
        } catch {
            authError = "Couldn't update profile. Check your connection."
            return false
        }
    }

    // MARK: - Private helpers

    /// Stores user state and credentials after a successful auth (server or local).
    @discardableResult
    private func completeLogin(email: String, password: String, displayName: String, token: String?) -> Bool {
        if let token = token {
            KeychainService.saveToken(token)
            APIService.shared.setAuthToken(token)
        }
        KeychainService.save(password: password, for: email)

        let user = User(email: email, displayName: displayName)
        currentUser = user
        userDirectory[email] = displayName
        saveUser()
        saveUserDirectory()
        return true
    }

    /// Local-only fallback when the server is unreachable.
    private func localLogin(email: String, password: String) -> Bool {
        guard let existingName = userDirectory[email] else {
            authError = "Account not found"
            return false
        }
        if let stored = KeychainService.load(for: email) {
            guard stored == password else {
                authError = "Incorrect password"
                return false
            }
        }
        let user = User(email: email, displayName: existingName)
        currentUser = user
        saveUser()
        return true
    }

    private func saveUser() {
        guard let user = currentUser else { return }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadUser() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else { return }
        currentUser = user
        // Keep directory up to date with the restored user
        userDirectory[user.email] = user.displayName
        saveUserDirectory()
    }

    private func saveUserDirectory() {
        if let encoded = try? JSONEncoder().encode(userDirectory) {
            UserDefaults.standard.set(encoded, forKey: userDirectoryKey)
        }
    }

    private func loadUserDirectory() {
        guard let data = UserDefaults.standard.data(forKey: userDirectoryKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        userDirectory = decoded
    }
}
