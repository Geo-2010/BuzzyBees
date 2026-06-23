//
//  APIService.swift
//  Buzzy-Bees
//

import Foundation

// MARK: - Response Models

struct EventsResponse: Codable {
    let events: [APIEvent]
    let total: Int?
    let page: Int?
    let perPage: Int?
}

// Supporting codable data types for new features
struct EchoData: Codable {
    let email: String
    let tag: String
    let ts: String
}

struct PlusOneData: Codable {
    let inviterEmail: String
    let guestName: String
    let ts: String
}

/// API event model — matches backend JSON structure
struct APIEvent: Codable {
    let id: String
    let title: String
    let type: String
    let location: String
    let date: String
    let createdAt: String?  // ISO8601, provided by server
    let description: String
    let userId: String
    let capacity: Int?
    let minimumAge: Int?
    let attendees: [String]
    let waitlist: [String]?
    let latitude: Double?
    let longitude: Double?

    // Features 1-6
    let swarmMode: Bool?
    let swarmMinAttendees: Int?
    let swarmDeadline: String?
    let locationHidden: Bool?
    let locationRevealThreshold: Int?
    let locationUnlocked: Bool?
    let buzzScore: Int?
    let enRouteUsers: [String]?
    let arrivedUsers: [String]?
    let echoes: [EchoData]?
    let plusOneGuests: [PlusOneData]?

    private func parseDate(_ dateString: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: dateString) { return d }
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        fallback.timeZone = TimeZone(identifier: "UTC")
        return fallback.date(from: dateString)
    }

    func toEvent() -> Event? {
        guard let uuid = UUID(uuidString: id),
              let eventType = EventType(rawValue: type),
              let eventDate = parseDate(date) else {
            return nil
        }

        let eventCreatedAt = createdAt.flatMap { parseDate($0) } ?? eventDate
        let iso = ISO8601DateFormatter()

        let eventEchoes: [EventEcho] = (echoes ?? []).map { e in
            EventEcho(email: e.email, tag: e.tag, ts: e.ts)
        }

        let plusOnes: [PlusOneGuest] = (plusOneGuests ?? []).map { p in
            PlusOneGuest(inviterEmail: p.inviterEmail, guestName: p.guestName, ts: p.ts)
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
            waitlist: waitlist ?? [],
            createdAt: eventCreatedAt,
            latitude: latitude,
            longitude: longitude,
            swarmMode: swarmMode ?? false,
            swarmMinAttendees: swarmMinAttendees,
            swarmDeadline: swarmDeadline.flatMap { iso.date(from: $0) },
            locationHidden: locationHidden ?? false,
            locationRevealThreshold: locationRevealThreshold,
            locationUnlocked: locationUnlocked ?? true,
            buzzScore: buzzScore ?? 0,
            enRouteUsers: enRouteUsers ?? [],
            arrivedUsers: arrivedUsers ?? [],
            echoes: eventEchoes,
            plusOneGuests: plusOnes
        )
    }

    static func from(_ event: Event) -> APIEvent {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return APIEvent(
            id: event.id.uuidString,
            title: event.title,
            type: event.type.rawValue,
            location: event.location,
            date: formatter.string(from: event.date),
            createdAt: formatter.string(from: event.createdAt),
            description: event.description,
            userId: event.userId,
            capacity: event.capacity,
            minimumAge: event.minimumAge,
            attendees: event.attendees,
            waitlist: event.waitlist,
            latitude: event.latitude,
            longitude: event.longitude,
            swarmMode: event.swarmMode,
            swarmMinAttendees: event.swarmMinAttendees,
            swarmDeadline: event.swarmDeadline.map { formatter.string(from: $0) },
            locationHidden: event.locationHidden,
            locationRevealThreshold: event.locationRevealThreshold,
            locationUnlocked: event.locationUnlocked,
            buzzScore: event.buzzScore,
            enRouteUsers: event.enRouteUsers,
            arrivedUsers: event.arrivedUsers,
            echoes: nil,        // not sent to server
            plusOneGuests: nil  // not sent to server
        )
    }
}

struct RSVPResponse: Codable {
    let message: String
    let attending: Bool
    let event: APIEvent
}

struct WaitlistResponse: Codable {
    let message: String
    let onWaitlist: Bool
    let position: Int?
    let event: APIEvent
}

struct TravelStatusResponse: Codable {
    let status: String
    let event: APIEvent
}

struct PlusOneResponse: Codable {
    let message: String
    let plusOnesRemaining: Int
    let event: APIEvent
}

struct ProfileResponse: Codable {
    let displayName: String
}

struct APIError: Codable {
    let error: String
}

/// Response from auth endpoints
struct AuthResponse: Codable {
    let token: String
    let displayName: String
}

// MARK: - Error Types

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case unauthorized
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
        case .unauthorized:
            return "Session expired. Please log in again."
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

// MARK: - API Service

@Observable
class APIService {
    static let shared = APIService()

    // MARK: - Configuration
    // NOTE: Switch to HTTPS before going to production.
    // Step 1: Set up a reverse proxy (nginx or Caddy) with a TLS cert on your server.
    // Step 2: Change the baseURL below to "https://your-domain.com"
    // Step 3: Remove or block direct HTTP access on port 5001.
    // See the DEPLOYMENT CHECKLIST comment at the top of backend/app.py for details.
    private let baseURL = "http://195.252.199.12:5001"

    var authToken: String?

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

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - Request Helpers

    private func authenticatedRequest(url: URL, method: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func handleUnauthorized() {
        NotificationCenter.default.post(name: .authTokenExpired, object: nil)
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/login") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(["email": email, "password": password])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 401 {
                throw APIServiceError.serverError("Invalid email or password")
            }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            return try decoder.decode(AuthResponse.self, from: data)
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func updateProfile(displayName: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/profile") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(["displayName": displayName])
        let request = authenticatedRequest(url: url, method: "PUT", body: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let result = try decoder.decode(ProfileResponse.self, from: data)
            return result.displayName
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/register") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode([
            "email": email,
            "password": password,
            "displayName": displayName,
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 409 {
                throw APIServiceError.serverError("An account with this email already exists")
            }
            if http.statusCode != 201 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            return try decoder.decode(AuthResponse.self, from: data)
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    // MARK: - Health Check

    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/health")!
        let (_, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    // MARK: - Events

    func fetchEvents(page: Int = 1, perPage: Int = 20) async throws -> (events: [Event], total: Int) {
        guard var components = URLComponents(string: "\(baseURL)/api/events") else {
            throw APIServiceError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
        ]
        guard let url = components.url else { throw APIServiceError.invalidURL }

        // Build request with optional auth header for blind location reveal
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let eventsResponse = try decoder.decode(EventsResponse.self, from: data)
            let events = eventsResponse.events.compactMap { $0.toEvent() }
            return (events, eventsResponse.total ?? events.count)
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func fetchEvent(id: UUID) async throws -> Event? {
        guard let url = URL(string: "\(baseURL)/api/events/\(id.uuidString)") else {
            throw APIServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 404 { return nil }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            return try decoder.decode(APIEvent.self, from: data).toEvent()
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func createEvent(_ event: Event) async throws -> Event {
        guard let url = URL(string: "\(baseURL)/api/events") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(APIEvent.from(event))
        let request = authenticatedRequest(url: url, method: "POST", body: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode != 201 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let created = try decoder.decode(APIEvent.self, from: data)
            guard let result = created.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return result
        } catch let e as APIServiceError { throw e }
        catch let e as EncodingError { throw APIServiceError.decodingError(e) }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func updateEvent(_ event: Event) async throws -> Event {
        guard let url = URL(string: "\(baseURL)/api/events/\(event.id.uuidString)") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(APIEvent.from(event))
        let request = authenticatedRequest(url: url, method: "PUT", body: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode == 403 { throw APIServiceError.serverError("Not authorized to edit this event") }
            if http.statusCode == 404 { throw APIServiceError.serverError("Event not found") }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let updated = try decoder.decode(APIEvent.self, from: data)
            guard let result = updated.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return result
        } catch let e as APIServiceError { throw e }
        catch let e as EncodingError { throw APIServiceError.decodingError(e) }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func deleteEvent(id: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/api/events/\(id.uuidString)") else {
            throw APIServiceError.invalidURL
        }
        let request = authenticatedRequest(url: url, method: "DELETE")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode == 403 { throw APIServiceError.serverError("Not authorized to delete this event") }
            if http.statusCode == 404 { throw APIServiceError.serverError("Event not found") }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
        } catch let e as APIServiceError { throw e }
        catch { throw APIServiceError.networkError(error) }
    }

    func toggleRSVP(eventId: UUID, userId: String) async throws -> (attending: Bool, event: Event) {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/rsvp") else {
            throw APIServiceError.invalidURL
        }
        // Server uses JWT identity; send empty JSON body
        let body = "{}".data(using: .utf8)
        let request = authenticatedRequest(url: url, method: "POST", body: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIServiceError.unknownError
            }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode == 400 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Bad request"
                throw APIServiceError.serverError(msg)
            }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let rsvpResponse = try decoder.decode(RSVPResponse.self, from: data)
            guard let event = rsvpResponse.event.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return (rsvpResponse.attending, event)
        } catch let e as APIServiceError { throw e }
        catch let e as EncodingError { throw APIServiceError.decodingError(e) }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func toggleWaitlist(eventId: UUID, userId: String) async throws -> (onWaitlist: Bool, position: Int?, event: Event) {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/waitlist") else {
            throw APIServiceError.invalidURL
        }
        let body = "{}".data(using: .utf8)
        let request = authenticatedRequest(url: url, method: "POST", body: body)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode == 400 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Bad request"
                throw APIServiceError.serverError(msg)
            }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error
                    ?? "Server returned status \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let wlResponse = try decoder.decode(WaitlistResponse.self, from: data)
            guard let event = wlResponse.event.toEvent() else {
                throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1))
            }
            return (wlResponse.onWaitlist, wlResponse.position, event)
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    // MARK: - Feature 4: En Route

    func updateTravelStatus(_ status: String, eventId: UUID) async throws -> Event {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/status") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(["status": status])
        let request = authenticatedRequest(url: url, method: "POST", body: body)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Server error \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let r = try decoder.decode(TravelStatusResponse.self, from: data)
            guard let event = r.event.toEvent() else { throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1)) }
            return event
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    // MARK: - Feature 5: Echoes

    func postEcho(eventId: UUID, tag: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/echo") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(["tag": tag])
        let request = authenticatedRequest(url: url, method: "POST", body: body)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode != 200 && http.statusCode != 201 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Server error \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
        } catch let e as APIServiceError { throw e }
        catch { throw APIServiceError.networkError(error) }
    }

    // MARK: - Feature 6: Plus-One Tokens

    func addPlusOne(eventId: UUID, guestName: String) async throws -> (plusOnesRemaining: Int, event: Event) {
        guard let url = URL(string: "\(baseURL)/api/events/\(eventId.uuidString)/plus_one") else {
            throw APIServiceError.invalidURL
        }
        let body = try encoder.encode(["guestName": guestName])
        let request = authenticatedRequest(url: url, method: "POST", body: body)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode == 401 { handleUnauthorized(); throw APIServiceError.unauthorized }
            if http.statusCode == 400 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Bad request"
                throw APIServiceError.serverError(msg)
            }
            if http.statusCode != 200 {
                let msg = (try? decoder.decode(APIError.self, from: data))?.error ?? "Server error \(http.statusCode)"
                throw APIServiceError.serverError(msg)
            }
            let r = try decoder.decode(PlusOneResponse.self, from: data)
            guard let event = r.event.toEvent() else { throw APIServiceError.decodingError(NSError(domain: "APIService", code: -1)) }
            return (r.plusOnesRemaining, event)
        } catch let e as APIServiceError { throw e }
        catch let e as DecodingError { throw APIServiceError.decodingError(e) }
        catch { throw APIServiceError.networkError(error) }
    }

    func fetchPlusOnesRemaining() async throws -> Int {
        guard let url = URL(string: "\(baseURL)/api/auth/plus_ones") else { throw APIServiceError.invalidURL }
        let request = authenticatedRequest(url: url, method: "GET")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIServiceError.unknownError }
            if http.statusCode != 200 { return 3 }
            struct PlusOnesResp: Codable { let plusOnesRemaining: Int }
            return (try? decoder.decode(PlusOnesResp.self, from: data))?.plusOnesRemaining ?? 3
        } catch { return 3 }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let authTokenExpired = Notification.Name("authTokenExpired")
}
