//
//  MainView.swift
//  Rural-Activities
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

        // Create vertical wave along the left edge
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

    @State private var showAddEvent = false
    @State private var showFilters = false
    @State private var waveOffset: CGFloat = 0

    private var displayedEvents: [Event] {
        eventManager.filteredEvents
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Layered background
                AppTheme.black.ignoresSafeArea()

                GeometryReader { geometry in
                    // Left vertical wave - very subtle
                    VerticalWaveShape(offset: waveOffset, amplitude: 25)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.gold.opacity(0.1), AppTheme.gold.opacity(0.03)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Second left wave layer
                    VerticalWaveShape(offset: waveOffset + 1, amplitude: 20)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.darkGold.opacity(0.08), AppTheme.gold.opacity(0.02)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    // Right vertical wave (mirrored)
                    VerticalWaveShape(offset: waveOffset + 0.5, amplitude: 25)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.gold.opacity(0.1), AppTheme.gold.opacity(0.03)],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .rotationEffect(.degrees(180))
                        .offset(x: geometry.size.width)

                    // Subtle corner glow - top right
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.gold.opacity(0.06), AppTheme.gold.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 250, height: 250)
                        .offset(x: geometry.size.width - 60, y: -30)

                    // Subtle corner glow - bottom left
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.gold.opacity(0.05), AppTheme.gold.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(x: -50, y: geometry.size.height - 100)
                }
                .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Connection status bar
                    if !eventManager.isOnline {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                            Text("Offline Mode")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.8)))
                        .padding(.top, 4)
                    }

                    if displayedEvents.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.darkGray)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                    )

                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 35))
                                    .foregroundStyle(AppTheme.gold)
                            }

                            Text("No Events")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text("Add your first event using the + button")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(AppTheme.darkGray.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(AppTheme.gold.opacity(0.2), lineWidth: 1)
                                )
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(displayedEvents) { event in
                                let isOwnEvent = event.userId == authManager.currentUser?.email
                                ZStack {
                                    NavigationLink(destination: EventDetailView(event: event)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    EventRowView(event: event, isOwnEvent: isOwnEvent)
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
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await eventManager.fetchEventsFromServer()
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { authManager.logout() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.gold)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(AppTheme.darkGray.opacity(0.6))
                            )
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showFilters = true }) {
                            Image(systemName: eventManager.activeFilters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.gold)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(AppTheme.darkGray.opacity(0.6))
                                )
                        }

                        Button(action: { showAddEvent = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.gold, AppTheme.darkGold],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: AppTheme.gold.opacity(0.3), radius: 5, x: 0, y: 2)
                                )
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
            }
            .sheet(isPresented: $showFilters) {
                FilterView()
            }
            .onAppear {
                // Refresh events from server when view appears
                eventManager.refresh()

                withAnimation(
                    .easeInOut(duration: 5)
                    .repeatForever(autoreverses: true)
                ) {
                    waveOffset = .pi * 2
                }
            }
        }
        .tint(AppTheme.gold)
    }
}

#Preview {
    MainView()
        .environment(AuthManager())
        .environment(EventManager())
}
