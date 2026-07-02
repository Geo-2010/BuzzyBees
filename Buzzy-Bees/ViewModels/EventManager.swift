//
//  EventManager.swift
//  Buzzy-Bees
//

import Foundation
import Network

enum SortOption: String, CaseIterable, Identifiable {
    case eventDate = "Event Date"
    case recentlyAdded = "Recently Added"
    case mostPopular = "Most RSVPs"
    case nearest = "Nearest"

    var id: String { rawValue }
}

struct FilterCriteria {
    var eventTypes: Set<EventType> = []
    var location: String = ""
    var keyword: String = ""
    var startDate: Date?
    var endDate: Date?

    var isEmpty: Bool {
        eventTypes.isEmpty && location.isEmpty && keyword.isEmpty
            && startDate == nil && endDate == nil
    }
}

@Observable
class EventManager {
    private let api = APIService.shared

    var events: [Event] = []
    var activeFilters = FilterCriteria()
    var sortOption: SortOption = .eventDate
    var isLoading = false
    var errorMessage: String?
    var isOnline = false

    // Pagination
    var currentPage = 1
    var hasMorePages = true
    var isLoadingMore = false
    private let perPage = 20

    // Stale data indicator — when the local cache was last synced with the server
    var lastSyncedAt: Date?

    // Location manager reference (set from app entry point)
    var locationManager: LocationManager?

    // Prevents concurrent RSVP toggles on the same event (race condition fix)
    private var pendingRSVPIds: Set<UUID> = []

    // Prevents concurrent waitlist toggles on the same event
    private var pendingWaitlistIds: Set<UUID> = []

    // Feature 13: Track known event IDs to detect new nearby events
    private var knownEventIds: Set<UUID> = []

    // Network path monitor for real-time connectivity
    private var networkMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.buzzybees.network.monitor")

    // File-based JSON storage (replaces UserDefaults — no size limit)
    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("events.json")
    }

    // Feature 6: Plus-One token count
    var plusOnesRemaining: Int = 3

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

        switch sortOption {
        case .eventDate:
            return result.sorted { $0.date < $1.date }
        case .recentlyAdded:
            return result.sorted { $0.createdAt > $1.createdAt }
        case .mostPopular:
            return result.sorted { $0.attendees.count > $1.attendees.count }
        case .nearest:
            return result.sorted { a, b in
                let distA = distanceForEvent(a)
                let distB = distanceForEvent(b)
                switch (distA, distB) {
                case let (da?, db?): return da < db
                case (_?, nil):      return true
                case (nil, _?):      return false
                case (nil, nil):     return a.date < b.date
                }
            }
        }
    }

    func distanceForEvent(_ event: Event) -> Double? {
        guard let lat = event.latitude, let lon = event.longitude else { return nil }
        return locationManager?.distanceToUser(latitude: lat, longitude: lon)
    }

    init() {
        loadEventsFromLocal()
        cleanupPastEvents()
        startNetworkMonitoring()
    }

    deinit {
        networkMonitor?.cancel()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let nowOnline = path.status == .satisfied
                if nowOnline && !(self?.isOnline ?? true) {
                    self?.refresh()
                }
                self?.isOnline = nowOnline
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Load / Fetch

    func loadEventsForUser(_ userId: String) {
        loadEventsFromLocal()
        Task { await fetchEventsFromServer() }
        cleanupPastEvents()
    }

    @MainActor
    func fetchEventsFromServer() async {
        isLoading = true
        errorMessage = nil
        currentPage = 1

        do {
            let (serverEvents, total) = try await api.fetchEvents(page: 1, perPage: perPage)
            isOnline = true
            hasMorePages = serverEvents.count < total
            lastSyncedAt = Date()

            // Feature 13: Track event IDs before merge to detect new nearby events
            let previousKnownIds = knownEventIds.isEmpty ? Set(events.map(\.id)) : knownEventIds

            // Merge: server is source of truth; push any local-only events up
            var mergedEvents = serverEvents
            for localEvent in events {
                if !mergedEvents.contains(where: { $0.id == localEvent.id }) {
                    do {
                        let synced = try await api.createEvent(localEvent)
                        mergedEvents.append(synced)
                    } catch {
                        mergedEvents.append(localEvent)
                    }
                }
            }

            events = mergedEvents
            knownEventIds = Set(mergedEvents.map(\.id))
            cleanupPastEvents()
            saveEventsToLocal()
            refreshPlusOnes()

            // Feature 13: Notify for up to 2 new nearby events (within 5km)
            let notificationManager = NotificationManager.shared
            let newNearbyEvents = mergedEvents
                .filter { !previousKnownIds.contains($0.id) }
                .filter { event in
                    guard let dist = distanceForEvent(event) else { return false }
                    return dist <= 5000
                }
            for event in newNearbyEvents.prefix(2) {
                notificationManager.notifyNewNearbyEvent(eventTitle: event.title, location: event.location)
            }
        } catch {
            isOnline = false
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func loadMoreEvents() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true

        let nextPage = currentPage + 1
        do {
            let (serverEvents, total) = try await api.fetchEvents(page: nextPage, perPage: perPage)
            isOnline = true
            currentPage = nextPage
            hasMorePages = events.count + serverEvents.count < total

            for event in serverEvents {
                if !events.contains(where: { $0.id == event.id }) {
                    events.append(event)
                }
            }
            cleanupPastEvents()
            saveEventsToLocal()
        } catch {
            isOnline = false
            errorMessage = "Couldn't load more events. \(error.localizedDescription)"
        }

        isLoadingMore = false
    }

    private var lastRefreshed: Date?

    func refresh() {
        if let last = lastRefreshed, Date().timeIntervalSince(last) < 60 { return }
        lastRefreshed = Date()
        Task { await fetchEventsFromServer() }
    }

    // MARK: - CRUD

    private let maxEventsPerDay = 5

    func eventsCreatedToday(by userId: String) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return events.filter {
            $0.userId == userId && calendar.isDate($0.createdAt, inSameDayAs: today)
        }.count
    }

    func canUserCreateEvent(_ userId: String) -> Bool {
        eventsCreatedToday(by: userId) < maxEventsPerDay
    }

    func addEvent(_ event: Event) -> Bool {
        guard canUserCreateEvent(event.userId) else { return false }
        events.append(event)
        saveEventsToLocal()
        Task { await syncEventToServer(event) }
        return true
    }

    @MainActor
    private func syncEventToServer(_ event: Event) async {
        do {
            let serverEvent = try await api.createEvent(event)
            isOnline = true
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = serverEvent
                saveEventsToLocal()
            }
        } catch {
            isOnline = false
        }
    }

    /// Update an existing event. Only the event creator can update.
    func updateEvent(_ updated: Event) {
        guard let index = events.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = events[index]
        events[index] = updated
        saveEventsToLocal()

        Task {
            await updateEventOnServer(updated, previous: previous)
        }
    }

    @MainActor
    private func updateEventOnServer(_ updated: Event, previous: Event) async {
        do {
            let serverEvent = try await api.updateEvent(updated)
            isOnline = true
            if let index = events.firstIndex(where: { $0.id == updated.id }) {
                events[index] = serverEvent
                saveEventsToLocal()
            }
        } catch {
            isOnline = false
            // Roll back
            if let index = events.firstIndex(where: { $0.id == updated.id }) {
                events[index] = previous
                saveEventsToLocal()
            }
            errorMessage = "Failed to update event. Changes have been reverted."
        }
    }

    func deleteEvent(_ event: Event) {
        let eventId = event.id
        let backup = event
        events.removeAll { $0.id == eventId }
        saveEventsToLocal()
        Task { await confirmDeletion(id: eventId, backup: backup) }
    }

    @MainActor
    private func confirmDeletion(id: UUID, backup: Event) async {
        do {
            try await api.deleteEvent(id: id)
            isOnline = true
        } catch {
            isOnline = false
            if !events.contains(where: { $0.id == id }) {
                events.append(backup)
                saveEventsToLocal()
            }
            errorMessage = "Failed to delete event. It has been restored."
        }
    }

    func deleteEvent(at offsets: IndexSet, from eventList: [Event]) {
        for index in offsets {
            deleteEvent(eventList[index])
        }
    }

    // MARK: - RSVP

    /// Toggle RSVP. Guards against concurrent toggles on the same event to prevent race conditions.
    func toggleAttendance(for eventId: UUID, userId: String) {
        guard !pendingRSVPIds.contains(eventId) else { return }
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }

        pendingRSVPIds.insert(eventId)

        let previousAttendees = events[index].attendees

        if events[index].attendees.contains(userId) {
            events[index].attendees.removeAll { $0 == userId }
        } else {
            guard !events[index].isFull else {
                pendingRSVPIds.remove(eventId)
                return
            }
            events[index].attendees.append(userId)
        }
        saveEventsToLocal()

        Task {
            await toggleAttendanceOnServer(
                eventId: eventId,
                userId: userId,
                previousAttendees: previousAttendees
            )
        }
    }

    @MainActor
    private func toggleAttendanceOnServer(
        eventId: UUID,
        userId: String,
        previousAttendees: [String]
    ) async {
        defer { pendingRSVPIds.remove(eventId) }
        do {
            let (_, updatedEvent) = try await api.toggleRSVP(eventId: eventId, userId: userId)
            isOnline = true
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].attendees = updatedEvent.attendees
                events[index].waitlist = updatedEvent.waitlist
                events[index].buzzScore = updatedEvent.buzzScore
                saveEventsToLocal()
            }
        } catch {
            isOnline = false
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].attendees = previousAttendees
                saveEventsToLocal()
            }
            errorMessage = "Failed to update RSVP. Please try again."
        }
    }

    // MARK: - Waitlist

    /// Toggle waitlist status. Only valid when event is full and user is not already attending.
    func toggleWaitlist(for eventId: UUID, userId: String) {
        guard !pendingWaitlistIds.contains(eventId) else { return }
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }

        pendingWaitlistIds.insert(eventId)

        let previousWaitlist = events[index].waitlist

        if events[index].waitlist.contains(userId) {
            events[index].waitlist.removeAll { $0 == userId }
        } else {
            events[index].waitlist.append(userId)
        }
        saveEventsToLocal()

        Task {
            await toggleWaitlistOnServer(
                eventId: eventId,
                userId: userId,
                previousWaitlist: previousWaitlist
            )
        }
    }

    @MainActor
    private func toggleWaitlistOnServer(
        eventId: UUID,
        userId: String,
        previousWaitlist: [String]
    ) async {
        defer { pendingWaitlistIds.remove(eventId) }
        do {
            let (_, _, updatedEvent) = try await api.toggleWaitlist(eventId: eventId, userId: userId)
            isOnline = true
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                let wasOnWaitlist = previousWaitlist.contains(userId)
                let isNowAttending = updatedEvent.attendees.contains(userId)
                // Feature 13: Notify if promoted from waitlist to attending
                if wasOnWaitlist && isNowAttending {
                    NotificationManager.shared.notifyWaitlistPromotion(eventTitle: updatedEvent.title)
                }
                events[index].waitlist = updatedEvent.waitlist
                events[index].attendees = updatedEvent.attendees
                saveEventsToLocal()
            }
        } catch {
            isOnline = false
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].waitlist = previousWaitlist
                saveEventsToLocal()
            }
            errorMessage = "Failed to update waitlist. Please try again."
        }
    }

    func isUserAttending(eventId: UUID, userId: String) -> Bool {
        events.first(where: { $0.id == eventId })?.attendees.contains(userId) ?? false
    }

    func isUserOnWaitlist(eventId: UUID, userId: String) -> Bool {
        events.first(where: { $0.id == eventId })?.waitlist.contains(userId) ?? false
    }

    func waitlistPosition(eventId: UUID, userId: String) -> Int? {
        guard let wl = events.first(where: { $0.id == eventId })?.waitlist,
              let idx = wl.firstIndex(of: userId) else { return nil }
        return idx + 1
    }

    func getEvent(by id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    // MARK: - Filters / Sort

    func applyFilters(_ filters: FilterCriteria) { activeFilters = filters }
    func clearFilters() { activeFilters = FilterCriteria() }

    /// Events created by a specific user
    func eventsCreatedBy(_ userId: String) -> [Event] {
        filteredEvents.filter { $0.userId == userId }
    }

    /// Events a specific user has RSVP'd to (but did not create)
    func eventsAttendedBy(_ userId: String) -> [Event] {
        filteredEvents.filter { $0.attendees.contains(userId) && $0.userId != userId }
    }

    // MARK: - Feature 3: Buzz helpers

    /// Returns true if event has 3+ RSVPs in the last 2 hours
    func isBuzzing(_ event: Event) -> Bool {
        event.buzzScore >= 3
    }

    // MARK: - Feature 4: En Route

    func updateTravelStatus(_ status: String, for eventId: UUID) {
        Task { await updateTravelStatusOnServer(status, eventId: eventId) }
    }

    @MainActor
    private func updateTravelStatusOnServer(_ status: String, eventId: UUID) async {
        do {
            let updated = try await api.updateTravelStatus(status, eventId: eventId)
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index] = updated
                saveEventsToLocal()
            }
        } catch {
            errorMessage = "Couldn't update travel status."
        }
    }

    // MARK: - Feature 5: Echoes

    func postEcho(for eventId: UUID, tag: String) {
        Task { await postEchoOnServer(eventId: eventId, tag: tag) }
    }

    @MainActor
    private func postEchoOnServer(eventId: UUID, tag: String) async {
        do {
            try await api.postEcho(eventId: eventId, tag: tag)
            // Refresh the event to get updated echoes
            if let refreshed = try? await api.fetchEvent(id: eventId) {
                if let index = events.firstIndex(where: { $0.id == eventId }) {
                    events[index] = refreshed
                    saveEventsToLocal()
                }
            }
        } catch {
            errorMessage = "Couldn't post echo."
        }
    }

    // MARK: - Feature 6: Plus-One

    func addPlusOne(for eventId: UUID, guestName: String) {
        Task { await addPlusOneOnServer(eventId: eventId, guestName: guestName) }
    }

    @MainActor
    private func addPlusOneOnServer(eventId: UUID, guestName: String) async {
        do {
            let (remaining, updated) = try await api.addPlusOne(eventId: eventId, guestName: guestName)
            plusOnesRemaining = remaining
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index] = updated
                saveEventsToLocal()
            }
        } catch {
            errorMessage = (error as? APIServiceError)?.errorDescription ?? "Couldn't add guest."
        }
    }

    func refreshPlusOnes() {
        Task {
            let count = try? await api.fetchPlusOnesRemaining()
            await MainActor.run { plusOnesRemaining = count ?? 3 }
        }
    }

    // MARK: - Persistence (File-based JSON — no UserDefaults size limit)

    func saveEventsToLocal() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-fatal: cached data simply won't be updated
        }
    }

    private func loadEventsFromLocal() {
        // Migrate from UserDefaults if we haven't yet
        if !FileManager.default.fileExists(atPath: storageURL.path),
           let legacy = UserDefaults.standard.data(forKey: "userEvents"),
           let decoded = try? JSONDecoder().decode([Event].self, from: legacy) {
            events = decoded
            saveEventsToLocal()
            UserDefaults.standard.removeObject(forKey: "userEvents")
            return
        }

        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else { return }
        events = decoded
    }

    private func cleanupPastEvents() {
        // Keep events in the echo window (up to 48h after end)
        let echoWindowCutoff = Date().addingTimeInterval(-48 * 60 * 60)
        let before = events.count
        events.removeAll { $0.date < echoWindowCutoff }
        if events.count != before {
            saveEventsToLocal()
        }
    }
}
