//
//  MapTabView.swift
//  Buzzy-Bees
//

import SwiftUI
import MapKit

struct MapTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var selectedEvent: Event?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.4259, longitude: -86.9081),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    private var eventsWithCoordinates: [Event] {
        eventManager.events.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private func coordinate(for event: Event) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: event.latitude!, longitude: event.longitude!)
    }

    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        ForEach(eventsWithCoordinates) { event in
            Annotation(event.title, coordinate: coordinate(for: event)) {
                EventAnnotationPin(event: event)
                    .onTapGesture { handleTap(event) }
            }
            .annotationTitles(.hidden)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    mapAnnotations
                }
                .mapStyle(.standard)
                .ignoresSafeArea(edges: .bottom)

                // Bottom sheet card for selected event
                if let event = selectedEvent {
                    EventMapCard(event: event, onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedEvent = nil
                        }
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90) // clear the tab bar
                }
            }
            .navigationTitle("Nearby Events")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await eventManager.fetchEventsFromServer() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.gold)
                            .padding(8)
                            .background(Circle().fill(AppTheme.darkGray.opacity(0.7)))
                    }
                }
            }
        }
    }

    private func handleTap(_ event: Event) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if selectedEvent?.id == event.id {
                selectedEvent = nil
            } else {
                selectedEvent = event
            }
        }
    }
}

// MARK: - Annotation Pin

private struct EventAnnotationPin: View {
    let event: Event

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppTheme.gold, AppTheme.darkGold], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .shadow(color: AppTheme.gold.opacity(0.5), radius: 4, x: 0, y: 2)

            Image(systemName: event.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.black)

            Circle()
                .fill(AppTheme.darkGold)
                .frame(width: 6, height: 6)
                .offset(y: 21)
        }
    }
}

// MARK: - Event Map Card (Bottom Sheet)

private struct EventMapCard: View {
    let event: Event
    let onDismiss: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: event.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle + dismiss
            HStack {
                Capsule()
                    .fill(AppTheme.mediumGray)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(AppTheme.mediumGray.opacity(0.5)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(AppTheme.gold.opacity(0.2))

            VStack(alignment: .leading, spacing: 10) {
                // Title + type badge
                HStack(alignment: .top, spacing: 10) {
                    // Type icon circle
                    ZStack {
                        Circle()
                            .fill(event.type.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(event.type.color.opacity(0.4), lineWidth: 1))

                        Image(systemName: event.type.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(event.type.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(event.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(event.type.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(event.type.color.opacity(0.15)))
                    }

                    Spacer()
                }

                // Date row
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold)
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                // Location row
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold)
                    Text(event.location)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                // View Details button
                NavigationLink(destination: EventDetailView(event: event)) {
                    HStack {
                        Text("View Details")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [AppTheme.gold, AppTheme.darkGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.darkGray)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.gold.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: -4)
        )
    }
}

#Preview {
    MapTabView()
        .environment(AuthManager())
        .environment(EventManager())
}
