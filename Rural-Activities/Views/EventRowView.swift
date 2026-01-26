//
//  EventRowView.swift
//  Rural-Activities
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    var isOwnEvent: Bool = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        HStack(spacing: 14) {
            // Circular icon
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

                Image(systemName: event.type.icon)
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.gold, AppTheme.darkGold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
            }

            Spacer()

            // Chevron indicator - only show for own events
            if isOwnEvent {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.gold.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.mediumGray.opacity(0.9), AppTheme.darkGray.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.gold.opacity(0.4), AppTheme.gold.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.black.opacity(0.3), radius: 8, x: 0, y: 4)
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
