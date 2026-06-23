//
//  Event.swift
//  Buzzy-Bees
//

import Foundation

// MARK: - Supporting Types for Features 5 & 6

/// A short vibe label left by an attendee after an event (Feature 5)
struct EventEcho: Codable, Identifiable {
    let email: String
    let tag: String
    let ts: String       // ISO8601 string — avoids Codable date strategy issues

    var id: String { email }

    var tsDate: Date {
        ISO8601DateFormatter().date(from: ts) ?? Date()
    }
}

/// A named guest added by an attending user spending a Plus-One token (Feature 6)
struct PlusOneGuest: Codable, Identifiable {
    let inviterEmail: String
    let guestName: String
    let ts: String       // ISO8601 string

    var id: String { "\(inviterEmail)-\(guestName)" }

    var tsDate: Date {
        ISO8601DateFormatter().date(from: ts) ?? Date()
    }
}

// MARK: - Event

struct Event: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: EventType
    var location: String
    var date: Date
    var description: String
    var userId: String
    var capacity: Int?      // nil means unlimited
    var minimumAge: Int?    // nil means all ages welcome
    var attendees: [String] // emails of users who RSVP'd
    var waitlist: [String]  // emails of users waitlisted (only populated when event is full)
    var createdAt: Date
    var latitude: Double?
    var longitude: Double?

    // Feature 1: Swarm Mode
    var swarmMode: Bool             // event evaporates if threshold not met by deadline
    var swarmMinAttendees: Int?     // minimum RSVPs required
    var swarmDeadline: Date?        // deadline for reaching minimum

    // Feature 2: Blind Location
    var locationHidden: Bool        // true = location masked until threshold met
    var locationRevealThreshold: Int? // RSVPs needed to reveal location
    var locationUnlocked: Bool      // server tells us if we can see the location

    // Feature 3: Buzz
    var buzzScore: Int              // RSVPs in the last 2 hours (server-computed)

    // Feature 4: En Route
    var enRouteUsers: [String]      // emails of users currently on their way
    var arrivedUsers: [String]      // emails of users already there

    // Feature 5: Echoes
    var echoes: [EventEcho]         // post-event vibe tags from attendees

    // Feature 6: Plus-One
    var plusOneGuests: [PlusOneGuest] // named guests added by attendees

    init(
        id: UUID = UUID(),
        title: String,
        type: EventType,
        location: String,
        date: Date,
        description: String,
        userId: String,
        capacity: Int? = nil,
        minimumAge: Int? = nil,
        attendees: [String] = [],
        waitlist: [String] = [],
        createdAt: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        swarmMode: Bool = false,
        swarmMinAttendees: Int? = nil,
        swarmDeadline: Date? = nil,
        locationHidden: Bool = false,
        locationRevealThreshold: Int? = nil,
        locationUnlocked: Bool = true,
        buzzScore: Int = 0,
        enRouteUsers: [String] = [],
        arrivedUsers: [String] = [],
        echoes: [EventEcho] = [],
        plusOneGuests: [PlusOneGuest] = []
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.location = location
        self.date = date
        self.description = description
        self.userId = userId
        self.capacity = capacity
        self.minimumAge = minimumAge
        self.attendees = attendees
        self.waitlist = waitlist
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.swarmMode = swarmMode
        self.swarmMinAttendees = swarmMinAttendees
        self.swarmDeadline = swarmDeadline
        self.locationHidden = locationHidden
        self.locationRevealThreshold = locationRevealThreshold
        self.locationUnlocked = locationUnlocked
        self.buzzScore = buzzScore
        self.enRouteUsers = enRouteUsers
        self.arrivedUsers = arrivedUsers
        self.echoes = echoes
        self.plusOneGuests = plusOneGuests
    }

    // MARK: - Computed Properties

    var spotsRemaining: Int? {
        guard let capacity = capacity else { return nil }
        return max(0, capacity - attendees.count)
    }

    var isFull: Bool {
        guard let capacity = capacity else { return false }
        return attendees.count >= capacity
    }

    /// True when swarm mode is active and the deadline has not yet passed
    var isSwarmActive: Bool {
        guard swarmMode, let deadline = swarmDeadline else { return false }
        return deadline > Date()
    }

    /// True when swarm threshold has been met (or no swarm mode)
    var swarmThresholdMet: Bool {
        guard swarmMode, let min = swarmMinAttendees else { return true }
        return attendees.count >= min
    }

    /// True when event is within 6 hours of start and hasn't started yet
    var isHappeningSoon: Bool {
        let sixHours: TimeInterval = 6 * 60 * 60
        return date.timeIntervalSinceNow <= sixHours && date > Date()
    }

    /// True when event has ended but echo window is still open (48h)
    var isInEchoWindow: Bool {
        guard date < Date() else { return false }
        return Date().timeIntervalSince(date) < 48 * 60 * 60
    }

    /// Total headcount including plus-one guests
    var totalHeadcount: Int { attendees.count + plusOneGuests.count }
}
