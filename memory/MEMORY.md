# BuzzyBees Project Memory

## Project Overview
iOS event discovery app (Swift/SwiftUI) + Python/Flask backend.
- Backend: `backend/app.py`, SQLite DB, port 5001. Real server address lives in
  `Buzzy-Bees/Services/ServerConfig.swift` (gitignored — never put the real
  address in a tracked file; see `ServerConfig.example.swift` for the template)
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

## Improvements Applied (July 2026 — Update 3)
Since Update 2 the app grew substantially with 6 new backend features (Swarm Mode,
Blind Location, Buzz/momentum, En Route status, Post-Event Echoes, Plus-One tokens)
plus iOS-side additions (Feature 13 enhanced notifications, Feature 15 onboarding,
Memory Tiles, Event DNA). This round addressed the remaining items from Update 2:
- Notification re-ask permanent lockout: `NotificationManager.requestPermissionExplicitly()`
  + a "Notifications" row in ProfileView now let a user (re-)enable/deep-link to Settings
  any time, independent of the 3-prompt soft-ask cap (`promptCount` still throttles only
  the *unsolicited* auto-prompt in `Buzzy_BeesApp.swift`).
- Waitlist promotion notification only fired for the user whose own action freed a slot.
  The common case — someone *else* cancels and a different device gets promoted — never
  notified that user. Fixed by tracking `EventManager.currentUserId` (set on login in
  `loadEventsForUser` and again every relaunch via `MainView.onAppear` →
  `eventManager.setCurrentUser(...)`, since a warm relaunch skips LoginView entirely) and
  diffing waitlist membership across `fetchEventsFromServer()` syncs.
- Backend CSV-list handling (attendees/waitlist/en_route/arrived) was duplicated ~12x
  across `backend/app.py`. DRYed into `_csv_list()` / `_csv_join()` helpers — no schema
  or behavior change, just centralizes the encode/decode so a future move to a real
  join table only touches two functions. Verified via a scripted Flask test-client run
  (register → RSVP → waitlist → auto-promote → en-route/arrived) before/after.
- HTTPS and a full CSV→relational-table migration were deliberately NOT done this round:
  HTTPS needs an actual domain/cert the assistant can't provision, and the schema
  migration is invasive (touches nearly every endpoint) with zero test coverage in the
  repo to catch a regression — flagged to the user rather than done blind.

## Remaining Known Issues (Low priority)
- No HTTPS yet — requires SSL cert + domain on server (see deployment checklist in app.py)
- Attendees/waitlist/en_route/arrived still CSV text columns, not a join table (encode/decode
  now centralized in `_csv_list`/`_csv_join`, but the underlying schema is unchanged)
- No automated test suite exists for backend or iOS — any nontrivial backend change should
  be smoke-tested manually (see Update 3 test script pattern: spin a venv, use Flask's
  `test_client()`) since there's nothing to catch regressions otherwise
