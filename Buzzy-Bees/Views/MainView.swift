//
//  MainView.swift
//  Buzzy-Bees
//

import SwiftUI

// Vertical wave for main view background (runs along the side)
struct VerticalWaveShape: Shape {
    var offset: CGFloat
    var amplitude: CGFloat = 30

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: 0))

        for y in stride(from: 0, through: height, by: 1) {
            let relativeY = y / height
            let sine = sin((relativeY * .pi * 3) + offset)
            let x = width * 0.3 + (sine * amplitude)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

struct MainView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    var body: some View {
        TabView {
            EventsTab()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }

            MyEventsView()
                .tabItem {
                    Label("My Events", systemImage: "person.crop.circle")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "gear")
                }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
        .onAppear { applyTabBarStyle() }
    }

    private func applyTabBarStyle() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.black)

        // Selected item: gold
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.gold)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.gold)]

        // Normal item: dimmed white
        let dimmed = UIColor.white.withAlphaComponent(0.4)
        appearance.stackedLayoutAppearance.normal.iconColor = dimmed
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: dimmed]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Events Tab (the original main feed)

struct EventsTab: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var showAddEvent = false
    @State private var showFilters = false
    @State private var waveOffset: CGFloat = 0
    @State private var greeting = EventsTab.timeAwareGreeting()

    private static func timeAwareGreeting(for firstName: String? = nil) -> String {
        let name = firstName.map { ", \($0)" } ?? ""
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isWeekend = weekday == 1 || weekday == 7
        let isFriday = weekday == 6

        switch hour {
        case 5..<12:
            return ["Good morning\(name)!", "Rise and buzz\(name)!", "Morning plans\(name)?", "What's on today\(name)?"].randomElement()!
        case 12..<17:
            return ["Afternoon\(name)!", "Any plans later\(name)?", "What's the buzz\(name)?", "Where you headed\(name)?"].randomElement()!
        case 17..<21:
            if isFriday { return ["Friday night\(name)!", "TGIF\(name)! Who's out?", "Weekend starts now\(name)!"].randomElement()! }
            if isWeekend { return ["Weekend mode\(name)!", "Who's buzzing tonight\(name)?", "Let's go out\(name)!"].randomElement()! }
            return ["Evening plans\(name)?", "Meetup tonight\(name)?", "Feeling social\(name)?", "Who's buzzing\(name)?"].randomElement()!
        default:
            return ["Night owl\(name)?", "Still buzzing\(name)?", "Late night plans\(name)?", "Who's still out\(name)?"].randomElement()!
        }
    }

    private var displayedEvents: [Event] { eventManager.filteredEvents }

    /// Human-readable "last synced" label for the offline banner
    private var lastSyncedLabel: String {
        guard let synced = eventManager.lastSyncedAt else { return "never synced" }
        let elapsed = Date().timeIntervalSince(synced)
        if elapsed < 60 { return "synced just now" }
        if elapsed < 3600 { return "synced \(Int(elapsed / 60))m ago" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "synced at \(formatter.string(from: synced))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.black.ignoresSafeArea()

                GeometryReader { geometry in
                    VerticalWaveShape(offset: waveOffset, amplitude: 25)
                        .fill(LinearGradient(colors: [AppTheme.gold.opacity(0.25), AppTheme.gold.opacity(0.08)], startPoint: .leading, endPoint: .trailing))

                    VerticalWaveShape(offset: waveOffset + 1, amplitude: 20)
                        .fill(LinearGradient(colors: [AppTheme.darkGold.opacity(0.2), AppTheme.gold.opacity(0.05)], startPoint: .leading, endPoint: .trailing))

                    VerticalWaveShape(offset: waveOffset + 0.5, amplitude: 25)
                        .fill(LinearGradient(colors: [AppTheme.gold.opacity(0.25), AppTheme.gold.opacity(0.08)], startPoint: .trailing, endPoint: .leading))
                        .rotationEffect(.degrees(180))
                        .offset(x: geometry.size.width)

                    Circle()
                        .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.15), AppTheme.gold.opacity(0)], center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 260, height: 260)
                        .offset(x: geometry.size.width - 60, y: 100)

                    Circle()
                        .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.15), AppTheme.gold.opacity(0)], center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 260, height: 260)
                        .offset(x: -50, y: geometry.size.height - 100)

                    Circle()
                        .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.1), AppTheme.gold.opacity(0)], center: .center, startRadius: 0, endRadius: 200))
                        .frame(width: 400, height: 400)
                        .offset(x: geometry.size.width / 2 - 200, y: geometry.size.height / 2 - 200)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Offline banner with stale-data timestamp
                    if !eventManager.isOnline {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash").font(.caption)
                            Text("Offline — \(lastSyncedLabel)")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.85)))
                        .padding(.top, 4)
                    }

                    if displayedEvents.isEmpty {
                        Spacer()
                        let filtersActive = !eventManager.activeFilters.isEmpty
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.darkGray)
                                    .frame(width: 80, height: 80)
                                    .overlay(Circle().stroke(AppTheme.gold.opacity(0.3), lineWidth: 1))

                                Image(systemName: filtersActive ? "line.3.horizontal.decrease.circle" : "calendar.badge.exclamationmark")
                                    .font(.system(size: 35))
                                    .foregroundStyle(AppTheme.gold)
                            }

                            Text(filtersActive ? "No Matches" : "No Events")
                                .font(.title2).fontWeight(.semibold).foregroundStyle(.white)

                            Text(filtersActive ? "No events match your current filters." : "Add your first event using the + button")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)

                            if filtersActive {
                                Button("Clear Filters") { eventManager.clearFilters() }
                                    .font(.subheadline.bold()).foregroundStyle(AppTheme.gold)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(Capsule().stroke(AppTheme.gold.opacity(0.5), lineWidth: 1))
                            }
                        }
                        .padding(30)
                        .background(RoundedRectangle(cornerRadius: 25).fill(AppTheme.darkGray.opacity(0.5)).overlay(RoundedRectangle(cornerRadius: 25).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)))
                        Spacer()
                    } else {
                        List {
                            ForEach(displayedEvents) { event in
                                let isOwnEvent = event.userId == authManager.currentUser?.email
                                let userId = authManager.currentUser?.email ?? ""
                                let isAttending = eventManager.isUserAttending(eventId: event.id, userId: userId)
                                let isOnWaitlist = eventManager.isUserOnWaitlist(eventId: event.id, userId: userId)
                                let distance = eventManager.distanceForEvent(event)
                                ZStack {
                                    NavigationLink(destination: EventDetailView(event: event)) { EmptyView() }.opacity(0)
                                    EventRowView(
                                        event: event,
                                        isOwnEvent: isOwnEvent,
                                        isAttending: isAttending,
                                        isOnWaitlist: isOnWaitlist,
                                        distance: distance,
                                        buzzScore: event.buzzScore,
                                        isSwarmActive: event.isSwarmActive,
                                        swarmDeadline: event.swarmDeadline,
                                        swarmMinAttendees: event.swarmMinAttendees,
                                        attendeeCount: event.attendees.count
                                    )
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if isOwnEvent {
                                        Button(role: .destructive) {
                                            eventManager.deleteEvent(event)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .onAppear {
                                    if event.id == displayedEvents.last?.id {
                                        Task { await eventManager.loadMoreEvents() }
                                    }
                                }
                            }

                            if eventManager.isLoadingMore {
                                HStack { Spacer(); ProgressView().tint(AppTheme.gold); Spacer() }
                                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await eventManager.fetchEventsFromServer() }
                    }
                }
            }
            .navigationTitle(greeting)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showFilters = true }) {
                            Image(systemName: eventManager.activeFilters.isEmpty ? "arrow.up.arrow.down.circle" : "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 16, weight: .medium)).foregroundStyle(AppTheme.gold)
                                .padding(8).background(Circle().fill(AppTheme.darkGray.opacity(0.6)))
                        }

                        Button(action: { showAddEvent = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(.black)
                                .padding(8)
                                .background(Circle().fill(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: AppTheme.gold.opacity(0.3), radius: 5, x: 0, y: 2))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) { AddEventView() }
            .sheet(isPresented: $showFilters) { FilterView() }
            .onAppear {
                updateGreeting()
                eventManager.refresh()
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    waveOffset = .pi * 2
                }
            }
            // Re-generate greeting when the user updates their display name
            .onChange(of: authManager.currentUser?.displayName) { updateGreeting() }
        }
    }

    private func updateGreeting() {
        let firstName = authManager.currentUser?.displayName.split(separator: " ").first.map(String.init)
        greeting = EventsTab.timeAwareGreeting(for: firstName)
    }
}

#Preview {
    MainView()
        .environment(AuthManager())
        .environment(EventManager())
}
