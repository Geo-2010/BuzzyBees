//
//  OnboardingView.swift
//  Buzzy-Bees
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Welcome
                OnboardingPageView(
                    icon: nil,
                    emojiIcon: "🐝",
                    title: "Welcome to BuzzyBees",
                    subtitle: "Discover events happening around Purdue and West Lafayette",
                    pills: [],
                    showGetStarted: false,
                    onComplete: onComplete
                )
                .tag(0)

                // Page 2: Discover & RSVP
                OnboardingPageView(
                    icon: "calendar.badge.plus",
                    emojiIcon: nil,
                    title: "Find Your Vibe",
                    subtitle: "Browse events by type, location, and distance. RSVP with one tap and get reminders.",
                    pills: ["🐝 Swarm Mode", "📍 Blind Location", "🔥 The Buzz"],
                    showGetStarted: false,
                    onComplete: onComplete
                )
                .tag(1)

                // Page 3: Get Started
                OnboardingPageView(
                    icon: "person.2.fill",
                    emojiIcon: nil,
                    title: "Built for Purdue",
                    subtitle: "Connect with students and locals around West Lafayette. Use your @purdue.edu email to join.",
                    pills: [],
                    showGetStarted: true,
                    onComplete: onComplete
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .tint(AppTheme.gold)
            .animation(.easeInOut, value: currentPage)

            // Skip button (pages 0 and 1 only)
            if currentPage < 2 {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.gold.opacity(0.8))
                    .padding(.top, 56)
                    .padding(.trailing, 24)
                }
            }

            // Next / Get Started button at bottom
            VStack {
                Spacer()
                if currentPage < 2 {
                    Button(action: {
                        withAnimation {
                            currentPage += 1
                        }
                    }) {
                        Text("Next")
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
                    .padding(.bottom, 48)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct OnboardingPageView: View {
    let icon: String?
    let emojiIcon: String?
    let title: String
    let subtitle: String
    let pills: [String]
    let showGetStarted: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon area
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.gold.opacity(0.25), AppTheme.gold.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                if let emoji = emojiIcon {
                    Text(emoji)
                        .font(.system(size: 80))
                } else if let sfSymbol = icon {
                    Image(systemName: sfSymbol)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundStyle(AppTheme.gold)
                }
            }

            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Subtitle
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature pills
            if !pills.isEmpty {
                VStack(spacing: 10) {
                    ForEach(pills, id: \.self) { pill in
                        Text(pill)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppTheme.gold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(AppTheme.gold.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(AppTheme.gold.opacity(0.4), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.top, 8)
            }

            // Get Started button (page 3 only)
            if showGetStarted {
                Button(action: onComplete) {
                    Text("Get Started")
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
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
