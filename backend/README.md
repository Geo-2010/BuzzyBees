# BuzzyBees Backend - Node.js API

A lightweight REST API for managing community events, built with Express.js and SQLite.

## Prerequisites

- Node.js (v16 or higher)
- npm or yarn

## Installation

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

## Running the Server

### Development mode (with auto-restart):
```bash
npm run dev
```

### Production mode:
```bash
npm start
```

The server will start on `http://localhost:5001`

## API Endpoints

| Method | Endpoint | Description | Rate Limit |
|--------|----------|-------------|------------|
| GET | `/api/health` | Health check | 200/min |
| GET | `/api/events` | List all events (supports filters) | 200/min |
| GET | `/api/events/:id` | Get event by ID | 200/min |
| POST | `/api/events` | Create new event | 20/min |
| PUT | `/api/events/:id` | Update event | 20/min |
| DELETE | `/api/events/:id` | Delete event | 20/min |
| POST | `/api/events/:id/rsvp` | Toggle RSVP | 30/min |

### Query Parameters for GET /api/events

- `userId` - Filter by user ID
- `type` - Filter by event type (Sports, Party, Study Group, Meeting)
- `location` - Filter by location (partial match)

## Event Model

```json
{
  "id": "uuid",
  "title": "string",
  "type": "Sports | Party | Study Group | Meeting",
  "location": "string",
  "date": "ISO8601 datetime",
  "description": "string",
  "userId": "string",
  "capacity": "number (optional)",
  "minimumAge": "number (optional)",
  "attendees": ["array of user IDs"]
}
```

## Security Features

- CORS enabled for cross-origin requests
- Rate limiting (200 requests/minute default, stricter limits on write operations)
- Request payload size limit (50 KB)
- Input validation on all endpoints

## Database

- SQLite database stored in `events.db`
- Automatically created on first run
- Database schema managed by Sequelize ORM

## Migration from Python

This backend is a direct port from the original Flask/Python version, maintaining:
- Identical API endpoints and responses
- Same database schema (existing `events.db` file is compatible)
- Same rate limiting and security measures
- Same logging output format

You can safely switch between Python and Node.js backends without any client-side changes.
