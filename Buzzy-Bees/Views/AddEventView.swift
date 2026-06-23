//
//  AddEventView.swift
//  Buzzy-Bees
//

import SwiftUI

/// Used for both creating new events and editing existing ones.
/// Pass an existing `Event` to `editingEvent` to enter edit mode.
struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(EventManager.self) private var eventManager

    /// When non-nil, the view is in edit mode and will update this event instead of creating a new one.
    var editingEvent: Event? = nil

    @State private var title = ""
    @State private var type: EventType = .meeting
    @State private var location = ""
    @State private var date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var description = ""
    @State private var hasCapacityLimit = false
    @State private var capacity = 20
    @State private var hasAgeLimit = false
    @State private var minimumAge = 18
    @State private var showContentWarning = false
    @State private var contentWarningMessage = ""
    @State private var showRateLimitWarning = false
    @State private var showLocationWarning = false
    @State private var isSaving = false
    @State private var pendingCoords: (latitude: Double, longitude: Double)?
    @State private var geocodingFailed = false  // true when coords couldn't be found

    // Feature 1: Swarm Mode
    @State private var swarmMode = false
    @State private var swarmMinAttendees = 5
    @State private var swarmDeadline = Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date()

    // Feature 2: Blind Location
    @State private var locationHidden = false
    @State private var locationRevealThreshold = 10

    private var isEditing: Bool { editingEvent != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        description.trimmingCharacters(in: .whitespaces).count >= 10 &&
        date > Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    VStack(alignment: .trailing, spacing: 2) {
                        TextField("Title", text: $title)
                            .onChange(of: title) { _, newValue in
                                if newValue.count > 60 { title = String(newValue.prefix(60)) }
                            }
                        Text("\(title.count)/60")
                            .font(.caption2)
                            .foregroundStyle(title.count > 50 ? .orange : .white.opacity(0.35))
                    }

                    Picker("Type", selection: $type) {
                        ForEach(EventType.allCases) { eventType in
                            Label(eventType.rawValue, systemImage: eventType.icon)
                                .tag(eventType)
                        }
                    }

                    TextField("Location", text: $location)
                        .onChange(of: location) { _, _ in geocodingFailed = false }

                    // Show geocoding failure warning inline
                    if geocodingFailed {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Address not found on map — distance & \"Open in Maps\" won't work for this event.")
                                .font(.caption)
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                    }
                }

                Section("Date & Time") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    if date <= Date() {
                        Text("Event must be scheduled in the future.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .onChange(of: description) { _, newValue in
                            if newValue.count > 2000 { description = String(newValue.prefix(2000)) }
                        }
                    HStack {
                        if description.trimmingCharacters(in: .whitespaces).count < 10 {
                            Text("Min 10 characters required.")
                                .font(.caption)
                                .foregroundStyle(.orange.opacity(0.8))
                        } else {
                            Spacer()
                        }
                        Text("\(description.count)/2000")
                            .font(.caption2)
                            .foregroundStyle(description.count > 1800 ? .orange : .white.opacity(0.35))
                    }
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

                // MARK: Feature 1: Swarm Mode
                Section {
                    Toggle("Swarm Mode 🐝", isOn: $swarmMode)
                    if swarmMode {
                        Stepper("Min RSVPs needed: \(swarmMinAttendees)", value: $swarmMinAttendees, in: 2...100)
                        DatePicker("RSVP deadline", selection: $swarmDeadline, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        Text("Event evaporates if \(swarmMinAttendees) people don't commit by the deadline.")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                } header: {
                    Text("Swarm Mode")
                } footer: {
                    if !swarmMode {
                        Text("Set a minimum RSVP count — event auto-cancels if the crowd doesn't show up.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                // MARK: Feature 2: Blind Location
                Section {
                    Toggle("Hide location until threshold", isOn: $locationHidden)
                    if locationHidden {
                        Stepper("Unlock at \(locationRevealThreshold) RSVPs", value: $locationRevealThreshold, in: 1...500)
                        Text("Location stays hidden until \(locationRevealThreshold) people RSVP.")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                } header: {
                    Text("Blind Location")
                } footer: {
                    if !locationHidden {
                        Text("Keep the exact location a mystery — revealed only when enough people commit.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
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
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppTheme.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.gold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(AppTheme.gold)
                    } else {
                        Button(isEditing ? "Update" : "Save") {
                            validateAndSave()
                        }
                        .foregroundStyle(canSave ? AppTheme.gold : AppTheme.gold.opacity(0.4))
                        .disabled(!canSave)
                    }
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
            .alert("Location Not Found", isPresented: $showLocationWarning) {
                Button("Save Anyway") {
                    geocodingFailed = true
                    pendingCoords = nil
                    commitEvent()
                }
                Button("Edit Location", role: .cancel) { }
            } message: {
                Text("We couldn't find this address on the map. The event won't show a distance or work with Maps. Save anyway?")
            }
            .onAppear {
                // Populate fields when editing
                if let event = editingEvent {
                    title = event.title
                    type = event.type
                    location = event.location
                    date = event.date
                    description = event.description
                    if let cap = event.capacity {
                        hasCapacityLimit = true
                        capacity = cap
                    }
                    if let age = event.minimumAge {
                        hasAgeLimit = true
                        minimumAge = age
                    }
                    // Feature 1: Swarm Mode
                    swarmMode = event.swarmMode
                    swarmMinAttendees = event.swarmMinAttendees ?? 5
                    swarmDeadline = event.swarmDeadline ?? (Calendar.current.date(byAdding: .hour, value: 24, to: Date()) ?? Date())
                    // Feature 2: Blind Location
                    locationHidden = event.locationHidden
                    locationRevealThreshold = event.locationRevealThreshold ?? 10
                }
            }
        }
        .tint(AppTheme.gold)
        .preferredColorScheme(.dark)
    }

    // MARK: - Save Logic

    private func validateAndSave() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        guard date > Date() else { return }  // canSave already guards this, belt-and-suspenders

        let validation = ContentFilter.validateContent(title: trimmedTitle, description: trimmedDescription)
        if !validation.isValid {
            contentWarningMessage = validation.errorMessage ?? "Please remove inappropriate content and try again."
            showContentWarning = true
            return
        }

        if !ContentFilter.isContentSafe(trimmedLocation) {
            contentWarningMessage = "The location contains inappropriate language."
            showContentWarning = true
            return
        }

        isSaving = true
        Task {
            let coords = await LocationManager.geocode(trimmedLocation)
            await MainActor.run {
                isSaving = false
                if let coords {
                    pendingCoords = coords
                    commitEvent()
                } else {
                    showLocationWarning = true
                }
            }
        }
    }

    private func commitEvent() {
        guard let userId = authManager.currentUser?.email else { return }

        if isEditing, var updated = editingEvent {
            // Edit mode — update existing event
            updated.title = title.trimmingCharacters(in: .whitespaces)
            updated.type = type
            updated.location = location.trimmingCharacters(in: .whitespaces)
            updated.date = date
            updated.description = description.trimmingCharacters(in: .whitespaces)
            updated.capacity = hasCapacityLimit ? capacity : nil
            updated.minimumAge = hasAgeLimit ? minimumAge : nil
            if let coords = pendingCoords {
                updated.latitude = coords.latitude
                updated.longitude = coords.longitude
            }
            // Feature 1: Swarm Mode
            updated.swarmMode = swarmMode
            updated.swarmMinAttendees = swarmMode ? swarmMinAttendees : nil
            updated.swarmDeadline = swarmMode ? swarmDeadline : nil
            // Feature 2: Blind Location
            updated.locationHidden = locationHidden
            updated.locationRevealThreshold = locationHidden ? locationRevealThreshold : nil
            eventManager.updateEvent(updated)
            dismiss()
        } else {
            // Create mode
            let event = Event(
                title: title.trimmingCharacters(in: .whitespaces),
                type: type,
                location: location.trimmingCharacters(in: .whitespaces),
                date: date,
                description: description.trimmingCharacters(in: .whitespaces),
                userId: userId,
                capacity: hasCapacityLimit ? capacity : nil,
                minimumAge: hasAgeLimit ? minimumAge : nil,
                latitude: pendingCoords?.latitude,
                longitude: pendingCoords?.longitude,
                swarmMode: swarmMode,
                swarmMinAttendees: swarmMode ? swarmMinAttendees : nil,
                swarmDeadline: swarmMode ? swarmDeadline : nil,
                locationHidden: locationHidden,
                locationRevealThreshold: locationHidden ? locationRevealThreshold : nil
            )

            if eventManager.addEvent(event) {
                dismiss()
            } else {
                showRateLimitWarning = true
            }
        }
    }
}

#Preview {
    AddEventView()
        .environment(AuthManager())
        .environment(EventManager())
}
