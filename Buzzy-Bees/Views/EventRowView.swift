//
//  EventRowView.swift
//  Rural-Activities
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    var isOwnEvent: Bool = false
    var isAttending: Bool = false
    var isOnWaitlist: Bool = false
    var distance: Double? = nil

    // Feature 3: Buzz momentum
    var buzzScore: Int = 0
    // Feature 1: Swarm Mode display
    var isSwarmActive: Bool = false
    var swarmDeadline: Date? = nil
    var swarmMinAttendees: Int? = nil
    var attendeeCount: Int = 0

    private var formattedDistance: String? {
        guard let distance else { return nil }
        if distance < 1 { return String(format: "%.0f m away", distance * 1000) }
        return String(format: "%.1f km away", distance)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(spacing: 14) {
            // Feature 7: DNA Fingerprint icon (replaces simple circular icon)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.mediumGray, AppTheme.darkGray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.gold.opacity(0.6), AppTheme.gold.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: AppTheme.gold.opacity(0.2), radius: 5, x: 0, y: 2)

                EventDNAView(event: event)
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold)
                    Text(event.location)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold.opacity(0.8))
                    Text(dateFormatter.string(from: event.date))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if let formattedDistance {
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(event.type.color.opacity(0.7))
                        Text(formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Feature 3: Buzz momentum badge
                if buzzScore >= 3 {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.caption)
                        Text("Buzzing")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }

                // Feature 1: Swarm countdown
                if isSwarmActive, let deadline = swarmDeadline, let minNeeded = swarmMinAttendees {
                    let remaining = minNeeded - attendeeCount
                    if remaining > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text("Needs \(remaining) more · evaporates \(deadline, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.9))
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if isAttending {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Going")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(AppTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.gold.opacity(0.15)))
                } else if isOnWaitlist {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.badge.fill")
                            .font(.caption2)
                        Text("Waitlisted")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                }

                if isOwnEvent {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppTheme.gold.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.mediumGray.opacity(0.4), AppTheme.darkGray.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.15), AppTheme.gold.opacity(0.1), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        EventRowView(event: Event(
            title: "Community Soccer Match",
            type: .sports,
            location: "Town Park",
            date: Date(),
            description: "Fun soccer game",
            userId: "test@test.com"
        ))
        .padding()
    }
}
