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
    //
    // Sign In and Sign Up are separate, explicit actions (rather than one form
    // that guesses which the user means) — a guess based on locally-cached
    // state gets out of sync with the server easily and produces confusing
    // "you already have an account" / "account not found" mismatches.

    /// Attempts server auth first, falls back to local Keychain auth if unreachable.
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard !email.isEmpty, !password.isEmpty else {
            authError = "Email and password are required"
            return false
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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
    }

    /// Registers a new account. A security question + at least one answer variant
    /// are required up front so the account can be recovered later without email.
    func signUp(
        email: String,
        password: String,
        displayName: String,
        securityQuestion: String,
        securityAnswers: [String]
    ) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuestion = securityQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAnswers = securityAnswers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            authError = "Email and password are required"
            return false
        }
        guard !trimmedName.isEmpty else {
            authError = "Display name is required"
            return false
        }
        guard !trimmedQuestion.isEmpty else {
            authError = "A security question is required"
            return false
        }
        guard !cleanedAnswers.isEmpty else {
            authError = "At least one security answer is required"
            return false
        }

        do {
            let response = try await APIService.shared.register(
                email: trimmedEmail,
                password: password,
                displayName: trimmedName,
                securityQuestion: trimmedQuestion,
                securityAnswers: cleanedAnswers
            )
            return completeLogin(email: trimmedEmail, password: password, displayName: response.displayName, token: response.token)
        } catch APIServiceError.serverError(let msg) {
            // Server reachable but rejected the request (bad input, duplicate email, etc.) — a real error.
            authError = msg
            return false
        } catch {
            // Server unreachable — create a local-only account so the app is still usable.
            // Nothing here syncs anywhere: no events from other people will show up, and
            // this account only exists on this device until it's created for real once
            // the server is back up.
            return completeLogin(email: trimmedEmail, password: password, displayName: trimmedName, token: nil)
        }
    }

    // MARK: - Forgot Password

    /// Step 1: look up the security question for an email. Returns nil (with
    /// `authError` set) if there's no account or the server is unreachable.
    func fetchSecurityQuestion(email: String) async -> String? {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else {
            authError = "Enter your email first"
            return nil
        }

        do {
            return try await APIService.shared.getSecurityQuestion(email: trimmedEmail)
        } catch APIServiceError.serverError(let msg) {
            authError = msg
            return nil
        } catch {
            authError = "Couldn't reach the server. Check your connection."
            return nil
        }
    }

    /// Step 2: verify the security answer and set a new password.
    func resetPassword(email: String, securityAnswer: String, newPassword: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard newPassword.count >= 6 else {
            authError = "Password must be at least 6 characters"
            return false
        }

        do {
            try await APIService.shared.resetPassword(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                securityAnswer: securityAnswer,
                newPassword: newPassword
            )
            return true
        } catch APIServiceError.serverError(let msg) {
            authError = msg
            return false
        } catch {
            authError = "Couldn't reach the server. Check your connection."
            return false
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
