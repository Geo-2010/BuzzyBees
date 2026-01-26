//
//  EventManager.swift
//  Rural-Activities
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case eventDate = "Event Date"
    case recentlyAdded = "Recently Added"
    case mostPopular = "Most RSVPs"

    var id: String { rawValue }
}

struct FilterCriteria {
    var eventTypes: Set<EventType> = []
    var location: String = ""
    var keyword: String = ""
    var startDate: Date?
    var endDate: Date?

    var isEmpty: Bool {
        eventTypes.isEmpty && location.isEmpty && keyword.isEmpty && startDate == nil && endDate == nil
    }
}

@Observable
class EventManager {
    private let eventsKey = "userEvents"
    private let hasLoadedMockDataKey = "hasLoadedMockData"
    private let api = APIService.shared

    var events: [Event] = []
    var activeFilters = FilterCriteria()
    var sortOption: SortOption = .eventDate
    var isLoading = false
    var errorMessage: String?
    var isOnline = false

    var filteredEvents: [Event] {
        var result = events

        if !activeFilters.eventTypes.isEmpty {
            result = result.filter { activeFilters.eventTypes.contains($0.type) }
        }

        if !activeFilters.location.isEmpty {
            result = result.filter { $0.location.localizedCaseInsensitiveContains(activeFilters.location) }
        }

        if !activeFilters.keyword.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(activeFilters.keyword) ||
                $0.description.localizedCaseInsensitiveContains(activeFilters.keyword)
            }
        }

        if let startDate = activeFilters.startDate {
            result = result.filter { $0.date >= startDate }
        }

        if let endDate = activeFilters.endDate {
            result = result.filter { $0.date <= endDate }
        }

        // Apply sorting
        switch sortOption {
        case .eventDate:
            return result.sorted { $0.date < $1.date }
        case .recentlyAdded:
            return result.sorted { $0.createdAt > $1.createdAt }
        case .mostPopular:
            return result.sorted { $0.attendees.count > $1.attendees.count }
        }
    }

    init() {
        loadEventsFromLocal()
        cleanupPastEvents()
        checkServerConnection()
    }

    /// Check if server is reachable
    private func checkServerConnection() {
        Task {
            do {
                isOnline = try await api.healthCheck()
            } catch {
                isOnline = false
            }
        }
    }

    func loadEventsForUser(_ userId: String) {
        // First load from local storage for immediate display
        loadEventsFromLocal()

        // Then try to sync with server
        Task {
            await fetchEventsFromServer()
        }

        cleanupPastEvents()
    }

    /// Fetch events from server and merge with local
    @MainActor
    func fetchEventsFromServer() async {
        isLoading = true
        errorMessage = nil

        do {
            let serverEvents = try await api.fetchEvents()
            isOnline = true

            // Merge server events with local (server is source of truth)
            var mergedEvents = serverEvents

            // Add any local-only events that haven't been synced
            for localEvent in events {
                if !mergedEvents.contains(where: { $0.id == localEvent.id }) {
                    // Try to sync local event to server
                    do {
                        let synced = try await api.createEvent(localEvent)
                        mergedEvents.append(synced)
                    } catch {
                        // Keep local event if sync fails
                        mergedEvents.append(localEvent)
                    }
                }
            }

            events = mergedEvents
            saveEventsToLocal()
        } catch {
            isOnline = false
            errorMessage = error.localizedDescription
            // Keep using local data on error
        }

        isLoading = false
    }

    /// Refresh events from server
    func refresh() {
        Task {
            await fetchEventsFromServer()
        }
    }

    /// Removes events whose date has passed
    private func cleanupPastEvents() {
        let now = Date()
        let previousCount = events.count
        events.removeAll { $0.date < now }
        if events.count != previousCount {
            saveEventsToLocal()
        }
    }

    private let maxEventsPerDay = 5

    /// Returns the number of events a user has created today
    func eventsCreatedToday(by userId: String) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return events.filter { event in
            event.userId == userId &&
            calendar.isDate(event.createdAt, inSameDayAs: today)
        }.count
    }

    /// Returns true if user can create more events today
    func canUserCreateEvent(_ userId: String) -> Bool {
        return eventsCreatedToday(by: userId) < maxEventsPerDay
    }

    func addEvent(_ event: Event) -> Bool {
        guard canUserCreateEvent(event.userId) else {
            return false
        }

        // Add locally first for immediate feedback
        events.append(event)
        saveEventsToLocal()

        // Then sync to server
        Task {
            await syncEventToServer(event)
        }

        return true
    }

    /// Sync a single event to server
    @MainActor
    private func syncEventToServer(_ event: Event) async {
        do {
            _ = try await api.createEvent(event)
            isOnline = true
        } catch {
            isOnline = false
            // Event is already saved locally, will sync later
        }
    }

    func deleteEvent(_ event: Event) {
        let eventId = event.id

        // Delete from server first, then locally
        Task {
            await deleteEventFromServer(eventId)
        }
    }

    @MainActor
    private func deleteEventFromServer(_ id: UUID) async {
        do {
            try await api.deleteEvent(id: id)
            isOnline = true

            // Only remove locally after successful server deletion
            events.removeAll { $0.id == id }
            saveEventsToLocal()
        } catch {
            isOnline = false
            errorMessage = "Failed to delete event. Please try again."
            // Don't remove locally if server delete failed
        }
    }

    func deleteEvent(at offsets: IndexSet, from eventList: [Event]) {
        for index in offsets {
            let event = eventList[index]
            deleteEvent(event)
        }
    }

    func applyFilters(_ filters: FilterCriteria) {
        activeFilters = filters
    }

    func clearFilters() {
        activeFilters = FilterCriteria()
    }

    func eventsForUser(_ userId: String) -> [Event] {
        filteredEvents.filter { $0.userId == userId }
    }

    func toggleAttendance(for eventId: UUID, userId: String) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }

        // Optimistic update locally first
        if events[index].attendees.contains(userId) {
            events[index].attendees.removeAll { $0 == userId }
        } else {
            // Only add if not full
            if !events[index].isFull {
                events[index].attendees.append(userId)
            }
        }
        saveEventsToLocal()

        // Sync with server
        Task {
            await toggleAttendanceOnServer(eventId: eventId, userId: userId)
        }
    }

    @MainActor
    private func toggleAttendanceOnServer(eventId: UUID, userId: String) async {
        do {
            let (_, updatedEvent) = try await api.toggleRSVP(eventId: eventId, userId: userId)
            isOnline = true

            // Update local event with server response
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].attendees = updatedEvent.attendees
                saveEventsToLocal()
            }
        } catch {
            isOnline = false
            // Keep local state, will sync later
        }
    }

    func isUserAttending(eventId: UUID, userId: String) -> Bool {
        guard let event = events.first(where: { $0.id == eventId }) else { return false }
        return event.attendees.contains(userId)
    }

    func getEvent(by id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    private func saveEventsToLocal() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }

    private func loadEventsFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else {
            return
        }
        events = decoded
    }
}
