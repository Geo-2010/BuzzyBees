//
//  User.swift
//  Rural-Activities
//

import Foundation

struct User: Codable, Equatable {
    let email: String
    let password: String
    let displayName: String

    /// Returns a privacy-friendly short name like "John D."
    var shortName: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            let firstName = parts[0]
            let lastInitial = parts[1].prefix(1)
            return "\(firstName) \(lastInitial)."
        }
        return displayName
    }
}
