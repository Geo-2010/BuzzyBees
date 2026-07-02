//
//  NotificationManager.swift
//  Buzzy-Bees
//

import Foundation
import UIKit
import UserNotifications

enum ReminderOption: String, CaseIterable, Identifiable {
    case oneDay = "1 day before"
    case fiveHours = "5 hours before"
    case oneHour = "1 hour before"
    case thirtyMinutes = "30 minutes before"

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .oneDay: return 24 * 60 * 60
        case .fiveHours: return 5 * 60 * 60
        case .oneHour: return 60 * 60
        case .thirtyMinutes: return 30 * 60
        }
    }

    var icon: String {
        switch self {
        case .oneDay: return "calendar"
        case .fiveHours: return "clock"
        case .oneHour: return "clock.badge"
        case .thirtyMinutes: return "timer"
        }
    }
}

@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private let remindersKey = "eventReminders"
    private let promptCountKey = "notificationPromptCount"
    private let maxPrompts = 3

    /// Whether the soft-ask prompt should be shown (used by views)
    var showPermissionPrompt = false

    private init() {}

    /// Number of times we've already prompted the user
    private var promptCount: Int {
        get { UserDefaults.standard.integer(forKey: promptCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptCountKey) }
    }

    /// Check current authorization and show soft-ask if needed.
    /// Call this at each strategic moment (launch, first RSVP, reminder tap).
    func promptIfNeeded() {
        guard promptCount < maxPrompts else { return }
        Task {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                showPermissionPrompt = true
            case .denied:
                showPermissionPrompt = true
            default:
                break
            }
        }
    }

    /// Called when user taps "Enable" on the soft-ask alert
    func userAcceptedPrompt() {
        promptCount += 1
        showPermissionPrompt = false

        Task {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            } else if settings.authorizationStatus == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }

    /// Called when user taps "Not Now" on the soft-ask alert
    func userDeclinedPrompt() {
        promptCount += 1
        showPermissionPrompt = false
    }

    /// Schedule reminders for an event
    func scheduleReminders(for eventId: UUID, eventTitle: String, eventDate: Date, reminders: Set<ReminderOption>) {
        // Cancel existing reminders for this event first
        cancelReminders(for: eventId)

        for reminder in reminders {
            let triggerDate = eventDate.addingTimeInterval(-reminder.timeInterval)

            // Don't schedule if the trigger date is in the past
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Event Reminder"
            content.body = "\(eventTitle) starts \(reminder.rawValue.replacingOccurrences(of: "before", with: "from now"))!"
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let identifier = notificationId(eventId: eventId, reminder: reminder)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            center.add(request)
        }

        // Save reminder preferences
        saveReminders(reminders, for: eventId)
    }

    /// Cancel all reminders for an event
    func cancelReminders(for eventId: UUID) {
        let identifiers = ReminderOption.allCases.map { notificationId(eventId: eventId, reminder: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        removeReminders(for: eventId)
    }

    /// Get saved reminder preferences for an event
    func savedReminders(for eventId: UUID) -> Set<ReminderOption> {
        guard let data = UserDefaults.standard.data(forKey: remindersKey),
              let allReminders = try? JSONDecoder().decode([String: [String]].self, from: data),
              let reminderStrings = allReminders[eventId.uuidString] else {
            return []
        }
        return Set(reminderStrings.compactMap { ReminderOption(rawValue: $0) })
    }

    private func notificationId(eventId: UUID, reminder: ReminderOption) -> String {
        "event_\(eventId.uuidString)_\(reminder.rawValue)"
    }

    private func saveReminders(_ reminders: Set<ReminderOption>, for eventId: UUID) {
        var allReminders = loadAllReminders()
        allReminders[eventId.uuidString] = reminders.map(\.rawValue)
        if let data = try? JSONEncoder().encode(allReminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }

    private func removeReminders(for eventId: UUID) {
        var allReminders = loadAllReminders()
        allReminders.removeValue(forKey: eventId.uuidString)
        if let data = try? JSONEncoder().encode(allReminders) {
            UserDefaults.standard.set(data, forKey: remindersKey)
        }
    }

    private func loadAllReminders() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: remindersKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    // MARK: - Feature 13: Enhanced Notification Types

    /// Notify the user that they've been promoted off the waitlist
    func notifyWaitlistPromotion(eventTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Spot opened up! 🎉"
        content.body = "You're off the waitlist for \(eventTitle). You're now attending!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "waitlist_\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(request)
    }

    /// Notify the user about a new nearby event
    func notifyNewNearbyEvent(eventTitle: String, location: String) {
        let content = UNMutableNotificationContent()
        content.title = "New event nearby 📍"
        content.body = "\(eventTitle) at \(location)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "nearby_\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(request)
    }

    /// Schedule a 1-hour-before notification for an event starting soon
    func scheduleEventStartingSoon(eventId: UUID, eventTitle: String, eventDate: Date) {
        let fireDate = eventDate.addingTimeInterval(-3600)
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Starting in 1 hour ⏰"
        content.body = "\(eventTitle) is coming up!"
        content.sound = .default
        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "soon_\(eventId.uuidString)", content: content, trigger: trigger)
        center.add(request)
    }
}
