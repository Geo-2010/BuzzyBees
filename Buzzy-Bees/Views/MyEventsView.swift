//
//  MyEventsView.swift
//  Buzzy-Bees
//

import SwiftUI

struct MyEventsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var selectedTab = 0   // 0 = Created, 1 = Attending
    @State private var showAddEvent = false
    @State private var waveOffset: CGFloat = 0

    private var userId: String { authManager.currentUser?.email ?? "" }

    private var createdEvents: [Event] {
        eventManager.events
            .filter { $0.userId == userId }
            .sorted { $0.date < $1.date }
    }

    private var attendingEvents: [Event] {
        eventManager.events
            .filter { $0.attendees.contains(userId) && $0.userId != userId }
            .sorted { $0.date < $1.date }
    }

    private var displayedEvents: [Event] {
        selectedTab == 0 ? createdEvents : attendingEvents
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.black.ignoresSafeArea()

                GeometryReader { geometry in
                    VerticalWaveShape(offset: waveOffset, amplitude: 25)
                        .fill(LinearGradient(colors: [AppTheme.gold.opacity(0.25), AppTheme.gold.opacity(0.08)], startPoint: .trailing, endPoint: .leading))
                        .scaleEffect(x: -1, anchor: .center)

                    VerticalWaveShape(offset: waveOffset + 1, amplitude: 20)
                        .fill(LinearGradient(colors: [AppTheme.darkGold.opacity(0.2), AppTheme.gold.opacity(0.05)], startPoint: .trailing, endPoint: .leading))
                        .scaleEffect(x: -1, anchor: .center)

                    Circle()
                        .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.15), AppTheme.gold.opacity(0)], center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 260, height: 260)
                        .offset(x: geometry.size.width - 200, y: 100)

                    Circle()
                        .fill(RadialGradient(colors: [AppTheme.gold.opacity(0.1), AppTheme.gold.opacity(0)], center: .center, startRadius: 0, endRadius: 200))
                        .frame(width: 400, height: 400)
                        .offset(x: geometry.size.width / 2 - 200, y: geometry.size.height / 2 - 200)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented control
                    Picker("", selection: $selectedTab) {
                        Text("Created (\(createdEvents.count))").tag(0)
                        Text("Attending (\(attendingEvents.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    if displayedEvents.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.darkGray)
                                    .frame(width: 72, height: 72)
                                    .overlay(Circle().stroke(AppTheme.gold.opacity(0.3), lineWidth: 1))
                                Image(systemName: selectedTab == 0 ? "plus.circle" : "calendar.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundStyle(AppTheme.gold)
                            }

                            Text(selectedTab == 0 ? "No Events Created" : "Not Attending Anything")
                                .font(.title3.bold())
                                .foregroundStyle(.white)

                            Text(selectedTab == 0
                                ? "Tap + to create your first event."
                                : "RSVP to events in the Events tab to see them here.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            if selectedTab == 0 {
                                Button("Create Event") { showAddEvent = true }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .leading, endPoint: .trailing)))
                            }
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(displayedEvents) { event in
                                let isAttending = eventManager.isUserAttending(eventId: event.id, userId: userId)
                                let isOnWaitlist = eventManager.isUserOnWaitlist(eventId: event.id, userId: userId)
                                let distance = eventManager.distanceForEvent(event)
                                ZStack {
                                    NavigationLink(destination: EventDetailView(event: event)) { EmptyView() }.opacity(0)
                                    EventRowView(
                                        event: event,
                                        isOwnEvent: selectedTab == 0,
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
                                    if selectedTab == 0 {
                                        Button(role: .destructive) {
                                            eventManager.deleteEvent(event)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await eventManager.fetchEventsFromServer() }
                    }
                }
            }
            .navigationTitle("My Events")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddEvent = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(8)
                            .background(
                                Circle().fill(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: AppTheme.gold.opacity(0.3), radius: 5, x: 0, y: 2)
                            )
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) { AddEventView() }
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    waveOffset = .pi * 2
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MyEventsView()
        .environment(AuthManager())
        .environment(EventManager())
}
