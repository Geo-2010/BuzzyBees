//
//  AddEventView.swift
//  Rural-Activities
//

import SwiftUI

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    @State private var title = ""
    @State private var type: EventType = .meeting
    @State private var location = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var hasCapacityLimit = false
    @State private var capacity = 20
    @State private var hasAgeLimit = false
    @State private var minimumAge = 18
    @State private var showContentWarning = false
    @State private var contentWarningMessage = ""
    @State private var showRateLimitWarning = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $type) {
                        ForEach(EventType.allCases) { eventType in
                            Label(eventType.rawValue, systemImage: eventType.icon)
                                .tag(eventType)
                        }
                    }

                    TextField("Location", text: $location)
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                Section("Capacity") {
                    Toggle("Limit attendance", isOn: $hasCapacityLimit)

                    if hasCapacityLimit {
                        Stepper("Max attendees: \(capacity)", value: $capacity, in: 2...500)
                    }
                }

                Section("Age Requirement") {
                    Toggle("Minimum age required", isOn: $hasAgeLimit)

                    if hasAgeLimit {
                        Picker("Minimum age", selection: $minimumAge) {
                            Text("18+").tag(18)
                            Text("21+").tag(21)
                            Text("25+").tag(25)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Community guidelines reminder
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .foregroundStyle(AppTheme.gold)
                        Text("Please keep content respectful and appropriate for all community members.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.black)
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.gold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .foregroundStyle(canSave ? AppTheme.gold : AppTheme.gold.opacity(0.4))
                    .disabled(!canSave)
                }
            }
            .alert("Inappropriate Content", isPresented: $showContentWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(contentWarningMessage)
            }
            .alert("Daily Limit Reached", isPresented: $showRateLimitWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can only create 5 events per day. Please try again tomorrow!")
            }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }

    private func saveEvent() {
        guard let userId = authManager.currentUser?.email else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        // Check content for inappropriate language
        let validation = ContentFilter.validateContent(title: trimmedTitle, description: trimmedDescription)

        if !validation.isValid {
            contentWarningMessage = validation.errorMessage ?? "Please remove inappropriate content and try again."
            showContentWarning = true
            return
        }

        // Also check location
        if !ContentFilter.isContentSafe(trimmedLocation) {
            contentWarningMessage = "The location contains inappropriate language. Please use respectful words."
            showContentWarning = true
            return
        }

        let event = Event(
            title: trimmedTitle,
            type: type,
            location: trimmedLocation,
            date: date,
            description: trimmedDescription,
            userId: userId,
            capacity: hasCapacityLimit ? capacity : nil,
            minimumAge: hasAgeLimit ? minimumAge : nil
        )

        if eventManager.addEvent(event) {
            dismiss()
        } else {
            showRateLimitWarning = true
        }
    }
}

#Preview {
    AddEventView()
        .environment(AuthManager())
        .environment(EventManager())
}
