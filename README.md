BuzzyBees
                                                                                
  A community event discovery app for iOS, with a Python/Flask REST API backend.
                                                                                
  Overview
                                                                                
  BuzzyBees lets users create, browse, and RSVP to local community events. The
  iOS app connects to a self-hosted Flask API that handles authentication and
  event storage.

  Features

  - Authentication — Register and log in with email/password; JWT tokens stored 
  in Keychain
  - Event Feed — Browse upcoming events sorted by date, with infinite scroll    
  pagination                                                                  
  - Event Categories — Sports, Party, Study Group, Meeting, Outdoor
  - RSVP — Toggle attendance on any event; capacity limits enforced server-side
  - Create & Delete — Post new events with location, date, description,         
  capacity, and minimum age; swipe to delete your own
  - Filtering — Filter the feed by event type or other criteria                 
  - Location — Optional GPS coordinates attached to events                    
  - Offline Indicator — Displays a banner when the device has no network
  connection                                                                    
  - Push Notifications — Notification support via NotificationManager
  - Past Event Cleanup — The server automatically removes expired events on each
   fetch                                                                      

  Architecture

  BuzzyBees/
  ├── Buzzy-Bees/               # iOS app (SwiftUI)
  │   ├── Models/               # Event, EventType, User                        
  │   ├── ViewModels/           # AuthManager, EventManager
  │   ├── Views/                # MainView, AddEventView, EventDetailView,      
  EventRowView, LoginView, FilterView                                           
  │   ├── Services/             # APIService, KeychainService, LocationManager,
  NotificationManager                                                           
  │   └── Theme.swift           # AppTheme colors and design tokens           
  └── backend/                  # Flask REST API
      ├── app.py                # All routes and models                         
      └── requirements.txt
                                                                                
  Backend Setup                                                               

  Requirements: Python 3.9+

  cd backend
  python -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
                                                                                
  Run the server:
                                                                                
  python app.py                                                               

  The API starts on port 5001. A SQLite database (events.db) is created
  automatically on first run.

  Environment variables:

  ┌────────────────┬─────────────────────────────────────────────────────────┐
  │    Variable    │                       Description                       │
  ├────────────────┼─────────────────────────────────────────────────────────┤  
  │ JWT_SECRET_KEY │ JWT signing secret. If omitted, a secret is             │
  │                │ auto-generated and saved to .jwt_secret.                │  
  └────────────────┴─────────────────────────────────────────────────────────┘

  ▎ Note: The server currently runs over plain HTTP. Use HTTPS with a reverse   
  proxy (nginx, Caddy) and a valid TLS certificate in production.
                                                                                
  API Endpoints                                                               

  ┌────────┬───────────────────────┬──────┬──────────────────────────────────┐
  │ Method │         Path          │ Auth │           Description            │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤
  │ GET    │ /api/health           │ No   │ Health check                     │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤
  │ POST   │ /api/auth/register    │ No   │ Register a new account           │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤  
  │ POST   │ /api/auth/login       │ No   │ Log in, receive JWT              │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤  
  │ GET    │ /api/events           │ No   │ List upcoming events (paginated) │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤
  │ GET    │ /api/events/<id>      │ No   │ Get a single event               │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤  
  │ POST   │ /api/events           │ Yes  │ Create an event                  │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤  
  │ PUT    │ /api/events/<id>      │ Yes  │ Update an event (creator only)   │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤
  │ DELETE │ /api/events/<id>      │ Yes  │ Delete an event (creator only)   │
  ├────────┼───────────────────────┼──────┼──────────────────────────────────┤  
  │ POST   │ /api/events/<id>/rsvp │ Yes  │ Toggle RSVP attendance           │
  └────────┴───────────────────────┴──────┴──────────────────────────────────┘  
                                                                              
  Rate limits: 200 req/min default; 10/min for registration; 20/min for login   
  and mutations.
                                                                                
  iOS App Setup                                                               

  1. Open Buzzy-Bees.xcodeproj in Xcode 15+
  2. Set the base URL in APIService.swift (baseURL) to point at your backend
  3. Select a simulator or device and run

  Requirements: iOS 17+, Swift 5.9+                                             
   
  Event Fields                                                                  
                                                                              
  ┌────────────────────┬──────────┬─────────────────────────────────────────┐
  │       Field        │ Required │               Constraints               │
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ title              │ Yes      │ Max 60 characters                       │
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ type               │ Yes      │ Sports, Party, Study Group, Meeting,    │
  │                    │          │ Outdoor                                 │   
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ location           │ Yes      │ Free text                               │   
  ├────────────────────┼──────────┼─────────────────────────────────────────┤ 
  │ date               │ Yes      │ ISO 8601, must be in the future         │
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ description        │ Yes      │ Free text                               │
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ capacity           │ No       │ 2–500                                   │
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ minimumAge         │ No       │ 18, 21, or 25                           │   
  ├────────────────────┼──────────┼─────────────────────────────────────────┤
  │ latitude /         │ No       │ GPS coordinates                         │   
  │ longitude          │          │                                         │ 
  └────────────────────┴──────────┴─────────────────────────────────────────┘   
