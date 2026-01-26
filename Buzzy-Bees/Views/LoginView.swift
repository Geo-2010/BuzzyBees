//
//  LoginView.swift
//  Rural-Activities
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

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showError = false
    @State private var waveOffset: CGFloat = 0
    @State private var isExistingUser = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Base black background
                AppTheme.black.ignoresSafeArea()

                // Layered wavy background
                GeometryReader { geometry in
                    // Bottom gold wave
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

                    // Middle darker wave
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

                    // Top subtle gold accent wave
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

                    // Top decorative curve
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

                // Content
                VStack(spacing: 30) {
                    Spacer()

                    // Logo section with curved container
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.darkGray)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [AppTheme.gold, AppTheme.gold.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: AppTheme.gold.opacity(0.3), radius: 15, x: 0, y: 5)

                            Text("🐝")
                                .font(.system(size: 50))
                        }

                        Text("BuzzyBees")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("Discover local events")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.gold.opacity(0.8))
                    }
                    .padding(.bottom, 20)

                    // Input fields with more curves
                    VStack(spacing: 18) {
                        // Only show name field for new users (not in directory yet)
                        if !isExistingUser {
                            TextField("Your Name", text: $displayName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.darkGray.opacity(0.8))
                                )
                                .foregroundStyle(.white)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [AppTheme.gold.opacity(0.6), AppTheme.gold.opacity(0.2)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .textContentType(.name)
                        }

                        TextField("Email", text: $email)
                            .onChange(of: email) { _, newValue in
                                isExistingUser = authManager.isExistingUser(email: newValue)
                            }
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(AppTheme.darkGray.opacity(0.8))
                            )
                            .foregroundStyle(.white)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [AppTheme.gold.opacity(0.6), AppTheme.gold.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(AppTheme.darkGray.opacity(0.8))
                            )
                            .foregroundStyle(.white)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [AppTheme.gold.opacity(0.6), AppTheme.gold.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .textContentType(.password)
                    }
                    .padding(.horizontal, 32)

                    // Curvy login button
                    Button(action: login) {
                        Text("Login")
                            .fontWeight(.bold)
                            .font(.title3)
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
                    .padding(.horizontal, 32)

                    if showError {
                        Text(isExistingUser ? "Please enter email and password" : "Please enter name, email and password")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }

                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 4)
                    .repeatForever(autoreverses: true)
                ) {
                    waveOffset = .pi * 2
                }
            }
        }
    }

    private func login() {
        if authManager.login(email: email, password: password, displayName: displayName) {
            eventManager.loadEventsForUser(email)
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
