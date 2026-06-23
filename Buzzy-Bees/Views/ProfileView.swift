//
//  ProfileView.swift
//  Buzzy-Bees
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var editingName = ""
    @State private var isEditingName = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var showLogoutConfirm = false

    private var currentUser: User? { authManager.currentUser }

    private var eventsCreatedCount: Int {
        guard let email = currentUser?.email else { return 0 }
        return eventManager.events.filter { $0.userId == email }.count
    }

    private var eventsAttendingCount: Int {
        guard let email = currentUser?.email else { return 0 }
        return eventManager.events.filter { $0.attendees.contains(email) && $0.userId != email }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                                .shadow(color: AppTheme.gold.opacity(0.4), radius: 12, x: 0, y: 4)

                            Text((currentUser?.displayName.prefix(1) ?? "?").uppercased())
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.top, 16)

                        // Display Name
                        VStack(spacing: 4) {
                            if isEditingName {
                                HStack(spacing: 10) {
                                    TextField("Display name", text: $editingName)
                                        .textFieldStyle(.plain)
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .autocorrectionDisabled()

                                    if isSaving {
                                        ProgressView().tint(AppTheme.gold).scaleEffect(0.8)
                                    } else {
                                        Button("Save") { saveDisplayName() }
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppTheme.gold)

                                        Button("Cancel") {
                                            isEditingName = false
                                            editingName = currentUser?.displayName ?? ""
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                HStack(spacing: 8) {
                                    Text(currentUser?.displayName ?? "—")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)

                                    Button {
                                        editingName = currentUser?.displayName ?? ""
                                        isEditingName = true
                                    } label: {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.gold.opacity(0.7))
                                    }
                                }
                            }

                            Text(currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        // Stats row — includes Plus-Ones remaining (Feature 6)
                        HStack(spacing: 0) {
                            StatCell(value: eventsCreatedCount, label: "Created")
                            Divider().frame(height: 40).background(AppTheme.gold.opacity(0.2))
                            StatCell(value: eventsAttendingCount, label: "Attending")
                            Divider().frame(height: 40).background(AppTheme.gold.opacity(0.2))
                            StatCell(value: eventManager.plusOnesRemaining, label: "Plus-Ones")
                        }
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.5)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)))
                        .padding(.horizontal)

                        // Info section
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: "Account")

                            InfoRow(icon: "envelope", label: "Email", value: currentUser?.email ?? "—")
                            Divider().background(AppTheme.gold.opacity(0.1)).padding(.leading, 48)
                            InfoRow(icon: "person.badge.key", label: "Role", value: "Community Member")
                        }
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.4)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.15), lineWidth: 1)))
                        .padding(.horizontal)

                        // Feature 5: Echo history from events the user organized
                        let organizerEchoes = eventManager.events
                            .filter { $0.userId == currentUser?.email && !$0.echoes.isEmpty }
                        if !organizerEchoes.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                SectionHeader(title: "Your Event Echoes")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(organizerEchoes) { event in
                                            VStack(spacing: 6) {
                                                EventDNAView(event: event)
                                                    .frame(width: 50, height: 50)
                                                    .cornerRadius(10)
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.gold.opacity(0.3), lineWidth: 1))
                                                // Show first 2 echo tags
                                                ForEach(event.echoes.prefix(2)) { echo in
                                                    Text(echo.tag)
                                                        .font(.system(size: 8))
                                                        .foregroundStyle(.white.opacity(0.7))
                                                        .lineLimit(1)
                                                }
                                            }
                                            .frame(width: 70)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.4)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.15), lineWidth: 1)))
                            .padding(.horizontal)
                        }

                        // Feature 7: Attended event fingerprint mosaic (Memory Tiles)
                        let attendedEvents = eventManager.events
                            .filter { $0.attendees.contains(currentUser?.email ?? "") }
                        if !attendedEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                SectionHeader(title: "Memory Tiles")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(attendedEvents.prefix(20)) { event in
                                        EventDNAView(event: event)
                                            .frame(height: 50)
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                            .background(RoundedRectangle(cornerRadius: 16).fill(AppTheme.darkGray.opacity(0.4)).overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gold.opacity(0.15), lineWidth: 1)))
                            .padding(.horizontal)
                        }

                        // Logout
                        Button(action: { showLogoutConfirm = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.red.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1)))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(authManager.authError ?? "Something went wrong.")
            }
            .alert("Sign Out?", isPresented: $showLogoutConfirm) {
                Button("Sign Out", role: .destructive) { authManager.logout() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to sign in again to access your events.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveDisplayName() {
        isSaving = true
        Task {
            let success = await authManager.updateDisplayName(to: editingName)
            await MainActor.run {
                isSaving = false
                if success {
                    isEditingName = false
                } else {
                    showError = true
                }
            }
        }
    }
}

private struct StatCell: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.gold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundStyle(AppTheme.gold.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(AppTheme.gold.opacity(0.7))
                .padding(.leading, 16)

            Text(label)
                .foregroundStyle(.white.opacity(0.6))
                .font(.subheadline)

            Spacer()

            Text(value)
                .foregroundStyle(.white.opacity(0.9))
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(EventManager())
}
