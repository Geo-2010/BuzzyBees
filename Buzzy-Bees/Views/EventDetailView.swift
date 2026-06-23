//
//  EventDetailView.swift
//  Buzzy-Bees
//

import SwiftUI
import UIKit

struct EventDetailView: View {
    let event: Event
    @Environment(EventManager.self) private var eventManager
    @Environment(AuthManager.self) private var authManager

    @State private var selectedReminders: Set<ReminderOption> = []
    @State private var showConfetti = false
    @State private var showEditEvent = false

    // Feature 4: En Route
    @State private var travelStatus: String = "none"  // "none", "en_route", "arrived"

    // Feature 5: Echoes
    @State private var showEchoInput = false
    @State private var echoTag = ""

    // Feature 6: Plus-One
    @State private var showPlusOneInput = false
    @State private var plusOneGuestName = ""

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }

    private var postedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private var currentEvent: Event {
        eventManager.getEvent(by: event.id) ?? event
    }

    private var isAttending: Bool {
        guard let userId = authManager.currentUser?.email else { return false }
        return eventManager.isUserAttending(eventId: event.id, userId: userId)
    }

    /// Distance from user in km, formatted
    private var distanceText: String? {
        guard let dist = eventManager.distanceForEvent(currentEvent) else { return nil }
        if dist < 1 {
            return String(format: "%.0f m away", dist * 1000)
        }
        return String(format: "%.1f km away", dist)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                rsvpSection
                if isAttending { remindersSection }
                Divider().background(AppTheme.gold.opacity(0.3))
                detailsSection
                echoSection
                swarmSection
                Spacer()
            }
            .padding()
        }
        .background(AppTheme.black)
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppTheme.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if currentEvent.userId == authManager.currentUser?.email {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showEditEvent = true }
                        .foregroundStyle(AppTheme.gold)
                }
            }
        }
        .sheet(isPresented: $showEditEvent) {
            AddEventView(editingEvent: currentEvent)
        }
        .sheet(isPresented: $showPlusOneInput) { plusOneSheet }
        .onAppear {
            selectedReminders = NotificationManager.shared.savedReminders(for: event.id)
            let userId = authManager.currentUser?.email ?? ""
            if currentEvent.enRouteUsers.contains(userId) { travelStatus = "en_route" }
            else if currentEvent.arrivedUsers.contains(userId) { travelStatus = "arrived" }
            else { travelStatus = "none" }
        }
        .alert("Enable Notifications?",
               isPresented: Binding(
                get: { NotificationManager.shared.showPermissionPrompt },
                set: { NotificationManager.shared.showPermissionPrompt = $0 }
               )) {
            Button("Enable") { NotificationManager.shared.userAcceptedPrompt() }
            Button("Not Now", role: .cancel) { NotificationManager.shared.userDeclinedPrompt() }
        } message: {
            Text("Enable notifications to get reminders before events you're attending!")
        }
    }

    // MARK: - Sections

    @ViewBuilder private var headerSection: some View {
        HStack(alignment: .top) {
            EventDNAView(event: event)
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.gold.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.gold.opacity(0.8))
                Text(event.title)
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                if currentEvent.buzzScore >= 3 {
                    Text("🔥 Buzzing")
                        .font(.caption.bold()).foregroundStyle(.orange)
                }
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder private var rsvpSection: some View {
        Button(action: toggleAttendance) {
            HStack(spacing: 12) {
                Image(systemName: isAttending ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isAttending ? AppTheme.gold : .white.opacity(0.5))
                    .symbolEffect(.bounce, value: isAttending)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAttending ? "You're Going!" : "I'm Going")
                        .font(.headline)
                        .foregroundStyle(isAttending ? AppTheme.gold : .white)
                    if let spots = currentEvent.spotsRemaining {
                        Text("\(spots) spots remaining")
                            .font(.caption)
                            .foregroundStyle(spots > 5 ? .white.opacity(0.6) : .orange)
                    }
                }
                Spacer()
                if currentEvent.isFull && !isAttending {
                    Text("FULL").font(.caption).fontWeight(.bold).foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.orange))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
            .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(isAttending ? AppTheme.gold : AppTheme.gold.opacity(0.3), lineWidth: isAttending ? 2 : 1))
        }
        .disabled(currentEvent.isFull && !isAttending)

        if currentEvent.isFull && !isAttending {
            let isOnWaitlist = eventManager.isUserOnWaitlist(eventId: event.id, userId: authManager.currentUser?.email ?? "")
            let position = eventManager.waitlistPosition(eventId: event.id, userId: authManager.currentUser?.email ?? "")
            Button(action: toggleWaitlist) {
                HStack(spacing: 10) {
                    Image(systemName: isOnWaitlist ? "clock.badge.checkmark.fill" : "clock.badge.plus")
                        .font(.title3)
                        .foregroundStyle(isOnWaitlist ? AppTheme.gold : .white.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isOnWaitlist ? "On Waitlist" : "Join Waitlist")
                            .font(.headline)
                            .foregroundStyle(isOnWaitlist ? AppTheme.gold : .white)
                        if let position, isOnWaitlist {
                            Text("Position #\(position)").font(.caption).foregroundStyle(.white.opacity(0.6))
                        } else if !isOnWaitlist {
                            Text("Get notified when a spot opens").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(isOnWaitlist ? AppTheme.gold.opacity(0.6) : AppTheme.gold.opacity(0.2), lineWidth: 1))
            }
        }

        if showConfetti {
            ConfettiView().allowsHitTesting(false).transition(.opacity)
        }

        if currentEvent.isHappeningSoon && isAttending {
            VStack(alignment: .leading, spacing: 10) {
                Label("Heading out?", systemImage: "car.fill")
                    .font(.headline).foregroundStyle(AppTheme.gold)
                HStack(spacing: 10) {
                    TravelButton(label: "On my way 🚗", status: "en_route", current: travelStatus) {
                        setTravelStatus(travelStatus == "en_route" ? "none" : "en_route")
                    }
                    TravelButton(label: "I'm there ✓", status: "arrived", current: travelStatus) {
                        setTravelStatus(travelStatus == "arrived" ? "none" : "arrived")
                    }
                }
                let enRoute = currentEvent.enRouteUsers.count
                let arrived = currentEvent.arrivedUsers.count
                if enRoute > 0 || arrived > 0 {
                    HStack(spacing: 16) {
                        if enRoute > 0 {
                            Label("\(enRoute) heading over", systemImage: "car")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        if arrived > 0 {
                            Label("\(arrived) already there", systemImage: "checkmark.circle")
                                .font(.caption).foregroundStyle(AppTheme.gold.opacity(0.8))
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reminders", systemImage: "bell")
                .font(.headline).foregroundStyle(AppTheme.gold)
            ForEach(ReminderOption.allCases) { option in
                Button { toggleReminder(option) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedReminders.contains(option) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedReminders.contains(option) ? AppTheme.gold : .white.opacity(0.4))
                        Image(systemName: option.icon)
                            .foregroundStyle(.white.opacity(0.7)).frame(width: 20)
                        Text(option.rawValue).foregroundStyle(.white.opacity(0.9))
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15).fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
        .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.4)))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(LinearGradient(colors: [.white.opacity(0.12), AppTheme.gold.opacity(0.15), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    @ViewBuilder private var detailsSection: some View {
        DetailRow(icon: "calendar", title: "Date & Time") {
            Text(dateFormatter.string(from: event.date)).foregroundStyle(.white.opacity(0.9))
        }
        DetailRow(icon: "mappin.and.ellipse", title: "Location") {
            VStack(alignment: .leading, spacing: 8) {
                Text(currentEvent.location)
                    .foregroundStyle(currentEvent.locationUnlocked ? .white.opacity(0.9) : .yellow.opacity(0.8))
                if let distanceText, currentEvent.locationUnlocked {
                    Text(distanceText).font(.caption).foregroundStyle(AppTheme.gold.opacity(0.7))
                }
                if currentEvent.locationUnlocked {
                    Button { openInMaps() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill").font(.caption)
                            Text("Open in Maps").font(.caption.bold())
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.gold))
                    }
                }
            }
        }
        if let capacity = currentEvent.capacity {
            DetailRow(icon: "person.3", title: "Capacity") {
                HStack {
                    Text("\(currentEvent.attendees.count) / \(capacity) attending").foregroundStyle(.white.opacity(0.9))
                    if currentEvent.isFull { Text("• Full").foregroundStyle(.orange) }
                }
            }
        }
        if let minAge = currentEvent.minimumAge {
            DetailRow(icon: "person.badge.shield.checkmark", title: "Age Requirement") {
                Text("\(minAge)+ only").foregroundStyle(.orange)
            }
        }
        if !currentEvent.attendees.isEmpty {
            DetailRow(icon: "person.2", title: "Who's Going") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(currentEvent.attendees.prefix(10), id: \.self) { email in
                        HStack(spacing: 8) {
                            Circle().fill(AppTheme.gold.opacity(0.3)).frame(width: 24, height: 24)
                                .overlay(Text(authManager.shortName(for: email).prefix(1)).font(.caption2).fontWeight(.bold).foregroundStyle(AppTheme.gold))
                            Text(authManager.shortName(for: email)).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    if currentEvent.attendees.count > 10 {
                        Text("+ \(currentEvent.attendees.count - 10) more").font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        if !currentEvent.plusOneGuests.isEmpty || isAttending {
            DetailRow(icon: "person.badge.plus", title: "Guests") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(currentEvent.plusOneGuests) { guest in
                        HStack(spacing: 8) {
                            Circle().fill(AppTheme.gold.opacity(0.2)).frame(width: 24, height: 24)
                                .overlay(Text("G").font(.caption2).fontWeight(.bold).foregroundStyle(AppTheme.gold))
                            Text(guest.guestName).foregroundStyle(.white.opacity(0.9))
                            Text("via \(authManager.shortName(for: guest.inviterEmail))").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    if isAttending && eventManager.plusOnesRemaining > 0 {
                        let tokenLabel = eventManager.plusOnesRemaining == 1 ? "token" : "tokens"
                        Button { showPlusOneInput = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                Text("Bring a guest (\(eventManager.plusOnesRemaining) \(tokenLabel) left)").font(.subheadline)
                            }
                            .foregroundStyle(AppTheme.gold)
                        }
                    }
                }
            }
        }
        if !event.description.isEmpty {
            DetailRow(icon: "doc.text", title: "Description") {
                Text(event.description).foregroundStyle(.white.opacity(0.7))
            }
        }
        Divider().background(AppTheme.gold.opacity(0.3))
        HStack {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(AppTheme.gold.opacity(0.6))
            Text("Posted on \(postedDateFormatter.string(from: event.createdAt))").font(.caption).foregroundStyle(.white.opacity(0.5))
        }
    }

    @ViewBuilder private var echoSection: some View {
        if currentEvent.isInEchoWindow {
            VStack(alignment: .leading, spacing: 10) {
                Label("Echoes", systemImage: "waveform").font(.headline).foregroundStyle(AppTheme.gold)
                echoTagCloud
                echoInputArea
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder private var echoTagCloud: some View {
        if currentEvent.echoes.isEmpty {
            Text("No echoes yet — be the first to leave a vibe.")
                .font(.caption).foregroundStyle(.white.opacity(0.5))
        } else {
            FlowLayout(spacing: 8) {
                ForEach(currentEvent.echoes) { echo in
                    Text(echo.tag).font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.darkGray.opacity(0.7)))
                        .overlay(Capsule().stroke(AppTheme.gold.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder private var echoInputArea: some View {
        if isAttending {
            let userEmail = authManager.currentUser?.email ?? ""
            let alreadyEchoed = currentEvent.echoes.contains { $0.email == userEmail }
            if alreadyEchoed {
                Text("✓ You left an echo").font(.caption).foregroundStyle(AppTheme.gold.opacity(0.7))
            } else if showEchoInput {
                EchoInputRow(tag: $echoTag, onPost: submitEcho)
            } else {
                Button("Leave an echo") { showEchoInput = true }
                    .font(.subheadline).foregroundStyle(AppTheme.gold)
            }
        }
    }

    @ViewBuilder private var swarmSection: some View {
        if currentEvent.swarmMode, let min = currentEvent.swarmMinAttendees, let deadline = currentEvent.swarmDeadline {
            let count = currentEvent.attendees.count
            let progress = Swift.min(Double(count) / Double(min), 1.0)
            VStack(alignment: .leading, spacing: 6) {
                Label("Swarm Mode 🐝", systemImage: "timer").font(.headline).foregroundStyle(.yellow)
                Text("\(count)/\(min) needed · deadline \(deadline, style: .relative)").font(.caption).foregroundStyle(.white.opacity(0.7))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.darkGray).frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progress >= 1.0 ? Color.green : Color.yellow)
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder private var plusOneSheet: some View {
        NavigationStack {
            Form {
                Section("Guest Name") {
                    TextField("Full name", text: $plusOneGuestName)
                }
                Section {
                    let tokenLabel = eventManager.plusOnesRemaining == 1 ? "token" : "tokens"
                    Text("You have \(eventManager.plusOnesRemaining) Plus-One \(tokenLabel) remaining this month.")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.black)
            .navigationTitle("Bring a Guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPlusOneInput = false }.foregroundStyle(AppTheme.gold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    let isEmpty = plusOneGuestName.trimmingCharacters(in: .whitespaces).isEmpty
                    Button("Add Guest") { addPlusOne() }
                        .foregroundStyle(isEmpty ? AppTheme.gold.opacity(0.4) : AppTheme.gold)
                        .disabled(isEmpty)
                }
            }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func toggleAttendance() {
        guard let userId = authManager.currentUser?.email else { return }
        let wasAttending = isAttending
        eventManager.toggleAttendance(for: event.id, userId: userId)

        if wasAttending {
            // Un-RSVPing — cancel all reminders
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            NotificationManager.shared.cancelReminders(for: event.id)
            selectedReminders = []
        } else {
            // RSVPing — heavy haptic + confetti
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(duration: 0.4)) {
                showConfetti = true
            }
            // Hide confetti after a moment
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation { showConfetti = false }
                }
            }
            // Strategic prompt #2: first RSVP
            NotificationManager.shared.promptIfNeeded()
        }
    }

    private func openInMaps() {
        if let lat = currentEvent.latitude, let lon = currentEvent.longitude {
            let encodedName = currentEvent.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                UIApplication.shared.open(url)
            }
        } else {
            let encodedLocation = currentEvent.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?q=\(encodedLocation)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func toggleWaitlist() {
        guard let userId = authManager.currentUser?.email else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        eventManager.toggleWaitlist(for: event.id, userId: userId)
    }

    private func toggleReminder(_ option: ReminderOption) {
        // Strategic prompt #3: tapping a reminder option
        NotificationManager.shared.promptIfNeeded()

        if selectedReminders.contains(option) {
            selectedReminders.remove(option)
        } else {
            selectedReminders.insert(option)
        }

        // Re-schedule all selected reminders
        NotificationManager.shared.scheduleReminders(
            for: event.id,
            eventTitle: event.title,
            eventDate: event.date,
            reminders: selectedReminders
        )
    }

    // Feature 4: En Route
    private func setTravelStatus(_ status: String) {
        travelStatus = status
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        eventManager.updateTravelStatus(status, for: event.id)
    }

    // Feature 5: Echoes
    private func submitEcho() {
        let tag = echoTag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        eventManager.postEcho(for: event.id, tag: tag)
        echoTag = ""
        showEchoInput = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // Feature 6: Plus-One
    private func addPlusOne() {
        let name = plusOneGuestName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        eventManager.addPlusOne(for: event.id, guestName: name)
        plusOneGuestName = ""
        showPlusOneInput = false
    }
}

// MARK: - Supporting Views

private struct EchoInputRow: View {
    @Binding var tag: String
    let onPost: () -> Void

    var body: some View {
        HStack {
            TextField("chill vibes, electric, chaotic fun...", text: $tag)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.darkGray))
                .onChange(of: tag) { _, v in
                    if v.count > 30 { tag = String(v.prefix(30)) }
                }
            Button("Post", action: onPost)
                .foregroundStyle(tag.isEmpty ? AppTheme.gold.opacity(0.4) : AppTheme.gold)
                .disabled(tag.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct DetailRow<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.gold)
            content
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

struct ConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, size: CGFloat, rotation: Double)] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(x: p.x, y: p.y)
                        .rotationEffect(.degrees(p.rotation))
                }
            }
            .onAppear {
                let colors: [Color] = [AppTheme.gold, .orange, .yellow, .white, AppTheme.darkGold]
                let width = geo.size.width
                particles = (0..<30).map { i in
                    (
                        id: i,
                        x: CGFloat.random(in: 0...width),
                        y: CGFloat.random(in: -20...0),
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 4...8),
                        rotation: Double.random(in: 0...360)
                    )
                }
                // Animate downward
                withAnimation(.easeIn(duration: 1.5)) {
                    particles = particles.map { p in
                        (
                            id: p.id,
                            x: p.x + CGFloat.random(in: -40...40),
                            y: p.y + CGFloat.random(in: 200...500),
                            color: p.color,
                            size: p.size,
                            rotation: p.rotation + Double.random(in: 180...720)
                        )
                    }
                }
            }
        }
    }
}

/// Simple left-to-right wrapping layout for tag clouds (Feature 5)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxY: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += rowHeight + spacing; x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxY = max(maxY, y + rowHeight)
        }
        return CGSize(width: width, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing; x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Travel status toggle button (Feature 4)
struct TravelButton: View {
    let label: String
    let status: String
    let current: String
    let action: () -> Void

    private var isSelected: Bool { current == status }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(AppTheme.darkGray.opacity(0.7))
                    )
                )
                .overlay(Capsule().stroke(isSelected ? AppTheme.gold : AppTheme.gold.opacity(0.3), lineWidth: 1))
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: Event(
            title: "Community Soccer Match",
            type: .sports,
            location: "Town Park Field",
            date: Date(),
            description: "Friendly soccer match open to all skill levels. Bring water and wear comfortable clothes. We'll have teams assigned on arrival.",
            userId: "test@test.com",
            capacity: 22,
            minimumAge: 18
        ))
    }
    .environment(AuthManager())
    .environment(EventManager())
}
