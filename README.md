  BuzzyBees                                                                     
                                                                                
  A community event discovery app for iOS, with a Node.js/Express REST API backend.
                                                                                
  Overview                                                  

  BuzzyBees lets users create, browse, and RSVP to local community events. The
  iOS app connects to a self-hosted Node.js API that handles event storage.

  Features                                                                      
   
  - User Identification — Events are associated with user IDs                                               
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
  └── backend/                  # Node.js/Express REST API
      ├── server.js             # Main server file with routes and models
      ├── package.json          # Node.js dependencies
      ├── app.py                # Legacy Python/Flask version (deprecated)
      └── requirements.txt      # Legacy Python dependencies (deprecated)                                                      
                                                            
  Backend Setup

  Requirements: Node.js 16+ and npm

  cd backend
  npm install

  Run the server:

  npm start              # Production mode
  npm run dev            # Development mode with auto-restart
  npm run pm2:start      # Background process with PM2 (recommended for production)

  PM2 Management (background process):
  npm run pm2:status     # Check app status
  npm run pm2:logs       # View live logs
  npm run pm2:restart    # Restart the app
  npm run pm2:stop       # Stop the app

  The API starts on port 5001. A SQLite database (events.db) is created
  automatically on first run. PM2 provides auto-restart on crashes and log
  management.

  ▎ Note: The server currently runs over plain HTTP. Use HTTPS with a reverse
  proxy (nginx, Caddy) and a valid TLS certificate in production.

  ▎ Legacy Python Backend: The previous Python/Flask version (app.py) is still
  available but deprecated. See backend/README.md for details.
                                                                                
  API Endpoints                                             

  - GET /api/health — Health check
  - GET /api/events — List all events (supports filtering by userId, type, location)
  - GET /api/events/<id> — Get a single event
  - POST /api/events — Create an event
  - PUT /api/events/<id> — Update an event
  - DELETE /api/events/<id> — Delete an event
  - POST /api/events/<id>/rsvp — Toggle RSVP attendance

  Rate limits: 200 req/min default; 20/min for mutations; 30/min for RSVP.

  See backend/README.md for detailed API documentation.                                                                
                                                            
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
