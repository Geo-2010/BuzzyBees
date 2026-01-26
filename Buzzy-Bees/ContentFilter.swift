//
//  ContentFilter.swift
//  Rural-Activities
//

import Foundation

struct ContentFilter {
    // List of inappropriate words/patterns to block
    // This is a basic list - in production, you'd use a more comprehensive solution
    private static let blockedWords: Set<String> = [
        // Slurs and hate speech (abbreviated/common variants included)
        "fuck", "shit", "ass", "damn", "bitch", "bastard", "crap",
        "dick", "cock", "pussy", "cunt", "whore", "slut",
        "fag", "faggot", "dyke", "retard", "retarded",
        "nigger", "nigga", "chink", "spic", "wetback", "kike",
        "cracker", "honky", "gook", "jap", "beaner",
        // Violence
        "kill", "murder", "rape", "terrorist", "bomb",
        // Drug references
        "cocaine", "heroin", "meth",
        // Common leetspeak variants
        "f*ck", "sh*t", "b*tch", "f**k", "s**t",
        "fuk", "fck", "btch", "azz"
    ]

    // Additional patterns to check (for creative spelling)
    private static let blockedPatterns: [String] = [
        "f+u+c+k", "s+h+i+t", "n+i+g", "f+a+g"
    ]

    /// Checks if the given text contains inappropriate content
    /// - Parameter text: The text to check
    /// - Returns: true if the content is safe, false if it contains blocked words
    static func isContentSafe(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Remove special characters and check
        let cleaned = lowercased.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)

        // Check against blocked words
        for word in blockedWords {
            let cleanedWord = word.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)

            // Check if the word appears in the text
            if cleaned.contains(cleanedWord) {
                return false
            }

            // Also check with word boundaries in original text
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {
                    return false
                }
            }
        }

        return true
    }

    /// Validates both title and description
    /// - Parameters:
    ///   - title: Event title
    ///   - description: Event description
    /// - Returns: A tuple with (isValid, errorMessage)
    static func validateContent(title: String, description: String) -> (isValid: Bool, errorMessage: String?) {
        if !isContentSafe(title) {
            return (false, "The title contains inappropriate language. Please use respectful words.")
        }

        if !isContentSafe(description) {
            return (false, "The description contains inappropriate language. Please use respectful words.")
        }

        return (true, nil)
    }
}
