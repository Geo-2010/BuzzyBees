//
//  LoginView.swift
//  Buzzy-Bees
//

import SwiftUI

// Wave shape for background decoration
struct WaveShape: Shape {
    var offset: CGFloat
    var amplitude: CGFloat = 50

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height * 0.5))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * .pi * 2) + offset)
            let y = (height * 0.5) + (sine * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

/// Shared capsule text-field styling for every field on this screen.
private struct AuthFieldStyle: ViewModifier {
    var hasError: Bool = false

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Capsule().fill(AppTheme.darkGray.opacity(0.8)))
            .foregroundStyle(.white)
            .overlay(
                Capsule().stroke(
                    LinearGradient(
                        colors: [
                            hasError ? Color.red.opacity(0.8) : AppTheme.gold.opacity(0.6),
                            hasError ? Color.red.opacity(0.4) : AppTheme.gold.opacity(0.2),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
            )
    }
}

private extension View {
    func authFieldStyle(hasError: Bool = false) -> some View {
        modifier(AuthFieldStyle(hasError: hasError))
    }
}

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    /// Sign In and Sign Up are deliberately separate screens reached via separate
    /// buttons — not one form that guesses which the user means from locally
    /// cached state, which drifts out of sync with the server and produces
    /// confusing "you already have an account" / "account not found" mismatches.
    private enum AuthScreen: Equatable {
        case welcome, signIn, signUp, forgotPassword
    }

    @State private var screen: AuthScreen = .welcome
    @State private var waveOffset: CGFloat = 0
    @State private var showError = false

    // Shared sign in / sign up fields
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    // Sign up: security question setup (multiple acceptable answer variants,
    // e.g. "three" / "3" / "3.0", in case the user doesn't recall the exact format)
    @State private var securityQuestion = ""
    @State private var securityAnswers: [String] = [""]

    // Forgot password flow
    @State private var securityQuestionText: String?
    @State private var resetAnswer = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var resetSuccess = false

    // Inline email format error shown before submission
    private var emailFormatError: String? {
        guard !email.isEmpty else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@"), let atIndex = trimmed.firstIndex(of: "@") else {
            return "Enter a valid email address"
        }
        let domain = String(trimmed[trimmed.index(after: atIndex)...])
        guard domain.contains(".") else { return "Enter a valid email address" }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 24) {
                    Spacer()
                    header(compact: screen != .welcome)
                        .padding(.bottom, screen == .welcome ? 20 : 4)

                    Group {
                        switch screen {
                        case .welcome: welcomeContent
                        case .signIn: signInContent
                        case .signUp: signUpContent
                        case .forgotPassword: forgotPasswordContent
                        }
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if screen != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: goBack) {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(AppTheme.gold)
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    waveOffset = .pi * 2
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        AppTheme.black.ignoresSafeArea()

        GeometryReader { geometry in
            WaveShape(offset: waveOffset, amplitude: 40)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.gold.opacity(0.3), AppTheme.gold.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: geometry.size.height * 0.6)
                .offset(y: geometry.size.height * 0.5)

            WaveShape(offset: waveOffset + 1, amplitude: 50)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.darkGray.opacity(0.8), AppTheme.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: geometry.size.height * 0.55)
                .offset(y: geometry.size.height * 0.55)

            WaveShape(offset: waveOffset + 2, amplitude: 30)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.gold.opacity(0.15), AppTheme.gold.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: geometry.size.height * 0.5)
                .offset(y: geometry.size.height * 0.6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.gold.opacity(0.2), AppTheme.gold.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: geometry.size.width * 0.6, y: -100)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.gold.opacity(0.15), AppTheme.gold.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: -50, y: geometry.size.height * 0.2)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func header(compact: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.darkGray)
                    .frame(width: compact ? 60 : 100, height: compact ? 60 : 100)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [AppTheme.gold, AppTheme.gold.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                    )
                    .shadow(color: AppTheme.gold.opacity(0.3), radius: compact ? 8 : 15, x: 0, y: 5)

                Text("🐝").font(.system(size: compact ? 30 : 50))
            }

            if !compact {
                Text("BuzzyBees")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Discover local events")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.gold.opacity(0.8))
            } else {
                Text(screenTitle)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private var screenTitle: String {
        switch screen {
        case .welcome: return ""
        case .signIn: return "Log In"
        case .signUp: return "Create Account"
        case .forgotPassword: return "Reset Password"
        }
    }

    // MARK: - Welcome

    private var welcomeContent: some View {
        VStack(spacing: 16) {
            primaryButton("Log In", isLoading: false) {
                resetTransientState()
                withAnimation { screen = .signIn }
            }
            secondaryButton("Create Account") {
                resetTransientState()
                withAnimation { screen = .signUp }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Sign In

    private var signInContent: some View {
        VStack(spacing: 18) {
            emailField

            SecureField("Password", text: $password)
                .onChange(of: password) { _, _ in showError = false }
                .authFieldStyle()
                .textContentType(.password)

            if !email.isEmpty && emailFormatError == nil {
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        securityQuestionText = nil
                        resetAnswer = ""
                        newPassword = ""
                        confirmNewPassword = ""
                        resetSuccess = false
                        showError = false
                        authManager.authError = nil
                        withAnimation { screen = .forgotPassword }
                    }
                    .font(.footnote.bold())
                    .foregroundStyle(AppTheme.gold.opacity(0.85))
                }
            }

            primaryButton("Log In", isLoading: authManager.isLoading) {
                Task { await performSignIn() }
            }

            if showError {
                errorBanner(authManager.authError ?? "Please enter email and password")
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Sign Up

    private var signUpContent: some View {
        VStack(spacing: 18) {
            emailField

            TextField("Your Name", text: $displayName)
                .authFieldStyle()
                .textContentType(.name)

            SecureField("Password", text: $password)
                .onChange(of: password) { _, _ in showError = false }
                .authFieldStyle()
                .textContentType(.newPassword)

            securityQuestionSetup

            primaryButton("Create Account", isLoading: authManager.isLoading) {
                Task { await performSignUp() }
            }

            if showError {
                errorBanner(authManager.authError ?? "Please fill in all fields")
            }
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder private var securityQuestionSetup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SECURITY QUESTION")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.gold.opacity(0.7))
            Text("Make up a question only you know the answer to — you'll use it to reset your password if you ever forget it.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))

            TextField("e.g. What was your first pet's name?", text: $securityQuestion)
                .authFieldStyle()

            ForEach(securityAnswers.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    TextField(i == 0 ? "Answer" : "Alternate answer (optional)", text: $securityAnswers[i])
                        .authFieldStyle()
                        .autocapitalization(.none)

                    if securityAnswers.count > 1 {
                        Button {
                            securityAnswers.remove(at: i)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.7))
                        }
                    }
                }
            }

            if securityAnswers.count < 3 {
                Button {
                    securityAnswers.append("")
                } label: {
                    Label("Add another acceptable answer", systemImage: "plus.circle")
                        .font(.footnote.bold())
                }
                .foregroundStyle(AppTheme.gold.opacity(0.85))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Forgot Password

    @ViewBuilder private var forgotPasswordContent: some View {
        VStack(spacing: 18) {
            if resetSuccess {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(AppTheme.gold)
                    Text("Password Reset!")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Log in with your new password.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 12)

                primaryButton("Back to Log In", isLoading: false) {
                    password = ""
                    withAnimation { screen = .signIn }
                }
            } else if let question = securityQuestionText {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR SECURITY QUESTION")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.gold.opacity(0.7))
                    Text(question)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.15), lineWidth: 1))

                TextField("Your answer", text: $resetAnswer)
                    .authFieldStyle()
                    .autocapitalization(.none)
                SecureField("New password", text: $newPassword)
                    .authFieldStyle()
                    .textContentType(.newPassword)
                SecureField("Confirm new password", text: $confirmNewPassword)
                    .authFieldStyle()
                    .textContentType(.newPassword)

                primaryButton("Reset Password", isLoading: authManager.isLoading) {
                    Task { await performResetPassword() }
                }

                if showError {
                    errorBanner(authManager.authError ?? "Please fill in all fields")
                }
            } else {
                Text("Enter your account email to find your security question.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                emailField

                primaryButton("Find My Account", isLoading: authManager.isLoading) {
                    Task { await performFetchSecurityQuestion() }
                }

                if showError {
                    errorBanner(authManager.authError ?? "Enter your account email")
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Shared field / button builders

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Email", text: $email)
                .onChange(of: email) { _, _ in showError = false }
                .authFieldStyle(hasError: emailFormatError != nil)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            if let emailFormatError, !email.isEmpty {
                Text(emailFormatError)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.leading, 12)
            }
        }
    }

    private func primaryButton(_ title: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .fontWeight(.bold)
                    .font(.title3)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.gold, AppTheme.darkGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: AppTheme.gold.opacity(0.4), radius: 10, x: 0, y: 5)
            )
            .foregroundStyle(.black)
        }
        .disabled(isLoading)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .font(.title3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(AppTheme.gold)
                .background(Capsule().stroke(AppTheme.gold.opacity(0.6), lineWidth: 1.5))
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(.red)
            .font(.caption)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.red.opacity(0.1)))
    }

    // MARK: - Navigation

    private func goBack() {
        withAnimation {
            switch screen {
            case .welcome:
                break
            case .signIn, .signUp:
                screen = .welcome
                resetTransientState()
                email = ""
            case .forgotPassword:
                screen = .signIn
                securityQuestionText = nil
                resetAnswer = ""
                newPassword = ""
                confirmNewPassword = ""
                resetSuccess = false
                showError = false
                authManager.authError = nil
            }
        }
    }

    private func resetTransientState() {
        password = ""
        displayName = ""
        securityQuestion = ""
        securityAnswers = [""]
        showError = false
        authManager.authError = nil
    }

    // MARK: - Actions

    private func performSignIn() async {
        showError = false
        let success = await authManager.signIn(email: email, password: password)
        if success {
            eventManager.loadEventsForUser(email.lowercased())
        } else {
            showError = true
        }
    }

    private func performSignUp() async {
        showError = false
        let success = await authManager.signUp(
            email: email,
            password: password,
            displayName: displayName,
            securityQuestion: securityQuestion,
            securityAnswers: securityAnswers
        )
        if success {
            eventManager.loadEventsForUser(email.lowercased())
        } else {
            showError = true
        }
    }

    private func performFetchSecurityQuestion() async {
        showError = false
        guard emailFormatError == nil, !email.isEmpty else {
            showError = true
            return
        }
        if let question = await authManager.fetchSecurityQuestion(email: email) {
            withAnimation { securityQuestionText = question }
        } else {
            showError = true
        }
    }

    private func performResetPassword() async {
        showError = false
        guard newPassword == confirmNewPassword else {
            authManager.authError = "Passwords don't match"
            showError = true
            return
        }
        let success = await authManager.resetPassword(
            email: email,
            securityAnswer: resetAnswer,
            newPassword: newPassword
        )
        if success {
            withAnimation { resetSuccess = true }
        } else {
            showError = true
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
        .environment(EventManager())
}
