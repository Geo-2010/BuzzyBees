# BuzzyBees Project Memory

## Project Overview
iOS event discovery app (Swift/SwiftUI) + Python/Flask backend.
- Backend: `backend/app.py`, SQLite DB, port 5001, IP `195.252.199.12`
- iOS: `Buzzy-Bees/` directory, uses `@Observable` (not ObservableObject)

## Architecture
- Auth: JWT tokens (flask-jwt-extended), bcrypt passwords. See `backend/app.py`.
- iOS auth: `AuthManager` (async login), token stored in Keychain via `KeychainService.saveToken()`
- API calls: `APIService.shared` — uses `authToken` as Bearer header on all write operations
- Token expiry: `Notification.Name.authTokenExpired` triggers auto-logout via `AuthManager`

## Key Files
- `backend/app.py` — Flask API with JWT auth, User model, Event model, waitlist column
- `Buzzy-Bees/Services/APIService.swift` — REST client, auth token management
- `Buzzy-Bees/Services/KeychainService.swift` — password + JWT token storage
- `Buzzy-Bees/ViewModels/AuthManager.swift` — async login, profile update, JWT handling
- `Buzzy-Bees/ViewModels/EventManager.swift` — file-based storage, RSVP + waitlist race condition guards
- `Buzzy-Bees/Views/MainView.swift` — TabView (Events / My Events / Profile) with dark tab bar
- `Buzzy-Bees/Views/ProfileView.swift` — NEW: display name editing, stats, sign-out
- `Buzzy-Bees/Views/MyEventsView.swift` — NEW: created/attending segmented view

## Improvements Applied (June 2026 — Update 1)
- HTTPS/JWT setup documented in deployment checklist at top of `backend/app.py`
- RSVP race condition fixed: `pendingRSVPIds` + `pendingWaitlistIds` guards in `EventManager`
- Events storage migrated from UserDefaults → `Documents/events.json` (no size limit, auto-migrates)
- Event editing UI: `AddEventView(editingEvent:)` — Edit button appears for event owners
- My Events tab: created/attending segmented picker
- Profile tab: editable display name, event stats, sign-out
- Waitlist: backend endpoint + frontend "Join Waitlist" button with position number
- Offline banner shows stale-data timestamp ("synced 5m ago")
- Input validation: description required (10+ chars), date must be future
- Geocoding failure shown inline in location field

## Improvements Applied (June 2026 — Update 2)
- FilterView "Clear All Filters" now applies+dismisses immediately (was only clearing local state)
- FilterView: Apply button disabled when date range is invalid (start > end), inline warning shown
- LoginView: removed duplicate `isLoading` state — now uses `authManager.isLoading` exclusively
- LoginView: inline email format validation with red border feedback
- LoginView: `.newPassword` textContentType for sign-up (triggers iOS strong password suggestion)
- EventRowView: "Waitlisted" badge (orange) shown when user is on waitlist
- TabView tab bar styled to match black/gold theme via `UITabBarAppearance`
- Greeting in Events tab now reactively updates when display name is changed in Profile
- Backend: server-side 5 events/day limit enforced (was frontend-only)
- Backend: description min 10 chars, max 2000 chars enforced on create + update
- Backend: CORS restricted to explicit origin list (env var `CORS_ORIGINS`, defaults to localhost)
- ContentFilter: Unicode normalization (`.toLatin` + `.stripDiacritics`) blocks Cyrillic lookalike bypasses

## Remaining Known Issues (Low priority)
- No HTTPS yet — requires SSL cert + domain on server (see deployment checklist in app.py)
- Attendees/waitlist stored as CSV in SQLite (fragile DB design)
- No push notifications when promoted from waitlist
- Notification re-ask blocked permanently after 3 denials (promptCount logic)
