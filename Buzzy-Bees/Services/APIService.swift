//
//  APIService.swift
//  Rural-Activities
//

import Foundation

/// API response wrapper for events list
struct EventsResponse: Codable {
    let events: [APIEvent]
}

/// API event model - matches backend JSON structure
struct APIEvent: Codable {
    let id: String
    let title: String
    let type: String
    let location: String
    let date: String
    let description: String
    let userId: String
    let capacity: Int?
    let minimumAge: Int?
    let attendees: [String]

    /// Convert to local Event model
    func toEvent() -> Event? {
        guard let uuid = UUID(uuidString: id),
              let eventType = EventType(rawValue: type),
              let eventDate = ISO8601DateFormatter().date(from: date) else {
            return nil
        }

        return Event(
            id: uuid,
            title: title,
            type: eventType,
            location: location,
            date: eventDate,
            description: description,
            userId: userId,
            capacity: capacity,
            minimumAge: minimumAge,
            attendees: attendees,
            createdAt: Date() // API doesn't track this, use current date
        )
    }

    /// Create from local Event model
    static func from(_ event: Event) -> APIEvent {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return APIEvent(
            id: event.id.uuidString,
            title: event.title,
            type: event.type.rawValue,
            location: event.location,
            date: formatter.string(from: event.date),
            description: event.description,
            userId: event.userId,
            capacity: event.capacity,
            minimumAge: event.minimumAge,
            attendees: event.attendees
        )
    }
}

/// RSVP response from API
struct RSVPResponse: Codable {
    let message: String
    let attending: Bool
    let event: APIEvent
}

/// Error response from API
struct APIError: Codable {
    let error: String
}

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

@Observable
class APIService {
    static let shared = APIService()

    // Base URL - change this if running on a different server
//    private let baseURL = "http://192.168.6.249:5001"
    private let baseURL = "http://195.252.199.12:5001"
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/health")!
        let (_, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return httpResponse.statusCode == 200
    }

    // MARK: - Events

    /// Fetch all events from server
    func fetchEvents() async throws -> [Event] {
        guard let url = URL(string: "\(baseURL)/api/events") else {
            throw APIServiceError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            let eventsResponse = try decoder.decode(EventsResponse.self, from: data)
            return eventsResponse.events.compactMap { $0.toEvent() }
        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Fetch a single event by ID
    func fetchEvent(id: UUID) async throws -> Event? {
        guard let url = URL(string: "\(baseURL)/api/events/\(id.uuidString)") else {
            throw APIServiceError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode == 404 {
                return nil
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            let apiEvent = try decoder.decode(APIEvent.self, from: data)
            return apiEvent.toEvent()
        } catch let error as APIServiceError {
            throw error
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Create a new event
    func createEvent(_ event: Event) async throws -> Event {
        guard let url = URL(string: "\(baseURL)/api/events") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiEvent = APIEvent.from(event)
        request.httpBody = try encoder.encode(apiEvent)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode != 201 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            let createdEvent = try decoder.decode(APIEvent.self, from: data)
            guard let result = createdEvent.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return result
        } catch let error as APIServiceError {
            throw error
        } catch let error as EncodingError {
            throw APIServiceError.decodingError(error)
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Update an existing event
    func updateEvent(_ event: Event) async throws -> Event {
        guard let url = URL(string: "\(baseURL)/api/events/\(event.id.uuidString)") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let apiEvent = APIEvent.from(event)
        request.httpBody = try encoder.encode(apiEvent)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode == 404 {
                throw APIServiceError.serverError("Event not found")
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            let updatedEvent = try decoder.decode(APIEvent.self, from: data)
            guard let result = updatedEvent.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return result
        } catch let error as APIServiceError {
            throw error
        } catch let error as EncodingError {
            throw APIServiceError.decodingError(error)
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Delete an event
    func deleteEvent(id: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/api/events/\(id.uuidString)") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode == 404 {
                throw APIServiceError.serverError("Event not found")
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }
        } catch let error as APIServiceError {
            throw error
        } catch {
            throw APIServiceError.networkError(error)
        }
    }

    /// Toggle RSVP for a user on an event
    func toggleRSVP(eventId: UUID, userId: String) async throws -> (attending: Bool, event: Event) {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/rsvp") else {
            throw APIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["userId": userId])

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }

            if httpResponse.statusCode == 404 {
                throw APIServiceError.serverError("Event not found")
            }

            if httpResponse.statusCode == 400 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? decoder.decode(APIError.self, from: data) {
                    throw APIServiceError.serverError(errorResponse.error)
                }
                throw APIServiceError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            let rsvpResponse = try decoder.decode(RSVPResponse.self, from: data)
            guard let event = rsvpResponse.event.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return (rsvpResponse.attending, event)
        } catch let error as APIServiceError {
            throw error
        } catch let error as EncodingError {
            throw APIServiceError.decodingError(error)
        } catch let error as DecodingError {
            throw APIServiceError.decodingError(error)
        } catch {
            throw APIServiceError.networkError(error)
        }
    }
}
