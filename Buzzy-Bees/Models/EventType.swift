//
//  EventType.swift
//  Rural-Activities
//

import Foundation

enum EventType: String, Codable, CaseIterable, Identifiable {
    case sports = "Sports"
    case party = "Party"
    case studyGroup = "Study Group"
    case meeting = "Meeting"
    case outdoor = "Outdoor"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sports: return "sportscourt"
        case .party: return "party.popper"
        case .studyGroup: return "book"
        case .meeting: return "person.3"
        case .outdoor: return "leaf"
        }
    }
}
