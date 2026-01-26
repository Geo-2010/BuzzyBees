//
//  EventDetailView.swift
//  Rural-Activities
//

import SwiftUI

struct EventDetailView: View {
    let event: Event
    @Environment(EventManager.self) private var eventManager
    @Environment(AuthManager.self) private var authManager

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with type icon
                HStack {
                    Image(systemName: event.type.icon)
                        .font(.title)
                        .foregroundStyle(AppTheme.gold)
                        .frame(width: 60, height: 60)
                        .background(AppTheme.darkGray)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.type.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.gold.opacity(0.8))
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 8)

                // RSVP Box
                Button(action: toggleAttendance) {
                    HStack(spacing: 12) {
                        Image(systemName: isAttending ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isAttending ? AppTheme.gold : .white.opacity(0.5))

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
                            Text("FULL")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.orange))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(AppTheme.darkGray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(isAttending ? AppTheme.gold : AppTheme.gold.opacity(0.3), lineWidth: isAttending ? 2 : 1)
                            )
                    )
                }
                .disabled(currentEvent.isFull && !isAttending)

                Divider()
                    .background(AppTheme.gold.opacity(0.3))

                // Date & Time
                DetailRow(icon: "calendar", title: "Date & Time") {
                    Text(dateFormatter.string(from: event.date))
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Location
                DetailRow(icon: "mappin.and.ellipse", title: "Location") {
                    Text(event.location)
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Capacity
                if let capacity = currentEvent.capacity {
                    DetailRow(icon: "person.3", title: "Capacity") {
                        HStack {
                            Text("\(currentEvent.attendees.count) / \(capacity) attending")
                                .foregroundStyle(.white.opacity(0.9))

                            if currentEvent.isFull {
                                Text("• Full")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // Age Requirement
                if let minAge = currentEvent.minimumAge {
                    DetailRow(icon: "person.badge.shield.checkmark", title: "Age Requirement") {
                        Text("\(minAge)+ only")
                            .foregroundStyle(.orange)
                    }
                }

                // Attendee List
                if !currentEvent.attendees.isEmpty {
                    DetailRow(icon: "person.2", title: "Who's Going") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(currentEvent.attendees.prefix(10), id: \.self) { email in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(AppTheme.gold.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(authManager.shortName(for: email).prefix(1))
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(AppTheme.gold)
                                        )
                                    Text(authManager.shortName(for: email))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            if currentEvent.attendees.count > 10 {
                                Text("+ \(currentEvent.attendees.count - 10) more")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }

                // Description
                if !event.description.isEmpty {
                    DetailRow(icon: "doc.text", title: "Description") {
                        Text(event.description)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Divider()
                    .background(AppTheme.gold.opacity(0.3))

                // Posted date
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppTheme.gold.opacity(0.6))
                    Text("Posted on \(postedDateFormatter.string(from: event.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

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
    }

    private func toggleAttendance() {
        guard let userId = authManager.currentUser?.email else { return }
        eventManager.toggleAttendance(for: event.id, userId: userId)
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
