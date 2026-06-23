//
//  User.swift
//  Buzzy-Bees
//

import Foundation

struct User: Codable, Equatable {
    let email: String
    let displayName: String

    // Custom decoding to handle old data that included a "password" field
    enum CodingKeys: String, CodingKey {
        case email, displayName, password
    }

    init(email: String, displayName: String) {
        self.email = email
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        // Ignore password if present in old data
        _ = try? container.decode(String.self, forKey: .password)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        // Never encode password
    }

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
