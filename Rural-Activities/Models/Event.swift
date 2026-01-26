//
//  Event.swift
//  Rural-Activities
//

import Foundation

struct Event: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: EventType
    var location: String
    var date: Date
    var description: String
    var userId: String
    var capacity: Int?  // nil means unlimited
    var minimumAge: Int?  // nil means all ages welcome
    var attendees: [String]  // list of user emails who RSVP'd
    var createdAt: Date  // when the event was posted

    init(id: UUID = UUID(), title: String, type: EventType, location: String, date: Date, description: String, userId: String, capacity: Int? = nil, minimumAge: Int? = nil, attendees: [String] = [], createdAt: Date = Date()) {
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
        self.createdAt = createdAt
    }

    var spotsRemaining: Int? {
        guard let capacity = capacity else { return nil }
        return max(0, capacity - attendees.count)
    }

    var isFull: Bool {
        guard let capacity = capacity else { return false }
        return attendees.count >= capacity
    }
}
