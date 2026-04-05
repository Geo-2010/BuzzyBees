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

  - JWT_SECRET_KEY — JWT signing secret. If omitted, a secret is auto-generated
  and saved to .jwt_secret.

  ▎ Note: The server currently runs over plain HTTP. Use HTTPS with a reverse   
  proxy (nginx, Caddy) and a valid TLS certificate in production.
                                                                                
  API Endpoints                                             

  - GET /api/health — Health check (no auth)                                    
  - POST /api/auth/register — Register a new account (no auth)
  - POST /api/auth/login — Log in, receive JWT (no auth)                        
  - GET /api/events — List upcoming events, paginated (no auth)
  - GET /api/events/<id> — Get a single event (no auth)                         
  - POST /api/events — Create an event (auth required)
  - PUT /api/events/<id> — Update an event, creator only (auth required)        
  - DELETE /api/events/<id> — Delete an event, creator only (auth required)     
  - POST /api/events/<id>/rsvp — Toggle RSVP attendance (auth required)
                                                                                
  Rate limits: 200 req/min default; 10/min for registration; 20/min for login
  and mutations.                                                                
                                                            
  iOS App Setup

  1. Open Buzzy-Bees.xcodeproj in Xcode 15+
  2. Set the base URL in APIService.swift (baseURL) to point at your backend
  3. Select a simulator or device and run                                       
   
  Requirements: iOS 17+, Swift 5.9+                                             
                                                            
  Event Fields

  - title (required) — Max 60 characters                                        
  - type (required) — Sports, Party, Study Group, Meeting, or Outdoor
  - location (required) — Free text                                             
  - date (required) — ISO 8601, must be in the future       
  - description (required) — Free text                                          
  - capacity (optional) — 2–500
  - minimumAge (optional) — 18, 21, or 25                                       
  - latitude / longitude (optional) — GPS coordinates       
