"""
Rural-Activities Flask API
A lightweight REST API for managing community events.
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
from dateutil import parser as date_parser
import uuid
import os

app = Flask(__name__)
CORS(app)

# Configure SQLite database
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(basedir, "events.db")}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)


class Event(db.Model):
    """Event model matching the iOS app's Event struct."""
    __tablename__ = 'events'

    id = db.Column(db.String(36), primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    type = db.Column(db.String(50), nullable=False)
    location = db.Column(db.String(200), nullable=False)
    date = db.Column(db.DateTime, nullable=False)
    description = db.Column(db.Text, nullable=False)
    user_id = db.Column(db.String(200), nullable=False)
    capacity = db.Column(db.Integer, nullable=True)
    minimum_age = db.Column(db.Integer, nullable=True)
    attendees = db.Column(db.Text, default='')  # Comma-separated emails

    def to_dict(self):
        """Convert event to dictionary for JSON response."""
        attendee_list = [a.strip() for a in self.attendees.split(',') if a.strip()]
        # Format date as ISO8601 with Z suffix for iOS compatibility
        date_str = self.date.strftime('%Y-%m-%dT%H:%M:%SZ')
        return {
            'id': self.id,
            'title': self.title,
            'type': self.type,
            'location': self.location,
            'date': date_str,
            'description': self.description,
            'userId': self.user_id,
            'capacity': self.capacity,
            'minimumAge': self.minimum_age,
            'attendees': attendee_list
        }

    @staticmethod
    def from_dict(data):
        """Create Event from dictionary."""
        event_id = data.get('id', str(uuid.uuid4()))
        attendees = data.get('attendees', [])
        if isinstance(attendees, list):
            attendees = ','.join(attendees)

        # Parse date - handle ISO format from iOS
        date_value = data.get('date')
        if isinstance(date_value, str):
            date_value = date_parser.parse(date_value)

        return Event(
            id=event_id,
            title=data['title'],
            type=data['type'],
            location=data['location'],
            date=date_value,
            description=data['description'],
            user_id=data['userId'],
            capacity=data.get('capacity'),
            minimum_age=data.get('minimumAge'),
            attendees=attendees
        )


# Create tables
with app.app_context():
    db.create_all()


# API Routes

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'ok', 'message': 'Rural-Activities API is running'})


@app.route('/api/events', methods=['GET'])
def get_events():
    """Get all events, optionally filtered by user_id."""
    print("\n" + "-"*50)
    print("GET /api/events - Fetching events")

    user_id = request.args.get('userId')
    event_type = request.args.get('type')
    location = request.args.get('location')

    print(f"  Filters: userId={user_id}, type={event_type}, location={location}")

    query = Event.query

    if user_id:
        query = query.filter_by(user_id=user_id)
    if event_type:
        query = query.filter_by(type=event_type)
    if location:
        query = query.filter(Event.location.ilike(f'%{location}%'))

    # Sort by date (most recent first)
    query = query.order_by(Event.date.asc())

    events = query.all()
    print(f"  Returning {len(events)} events")
    for e in events:
        print(f"    - {e.title} ({e.id})")
    print("-"*50 + "\n")
    return jsonify({'events': [e.to_dict() for e in events]})


@app.route('/api/events/<event_id>', methods=['GET'])
def get_event(event_id):
    """Get a single event by ID."""
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404
    return jsonify(event.to_dict())


@app.route('/api/events', methods=['POST'])
def create_event():
    """Create a new event."""
    print("\n" + "="*50)
    print("POST /api/events - Creating new event")
    print("="*50)

    data = request.get_json()
    print(f"Received data: {data}")

    if not data:
        print("ERROR: No data provided")
        return jsonify({'error': 'No data provided'}), 400

    required_fields = ['title', 'type', 'location', 'date', 'description', 'userId']
    missing = [f for f in required_fields if f not in data]
    if missing:
        print(f"ERROR: Missing fields: {missing}")
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    # Validate event type
    valid_types = ['Sports', 'Party', 'Study Group', 'Meeting', 'Outdoor']
    if data['type'] not in valid_types:
        print(f"ERROR: Invalid event type: {data['type']}")
        return jsonify({'error': f'Invalid event type. Must be one of: {", ".join(valid_types)}'}), 400

    try:
        event = Event.from_dict(data)
        db.session.add(event)
        db.session.commit()
        print(f"SUCCESS: Event created with ID: {event.id}")
        print(f"  Title: {event.title}")
        print(f"  Type: {event.type}")
        print(f"  Date: {event.date}")
        print(f"  User: {event.user_id}")
        print("="*50 + "\n")
        return jsonify(event.to_dict()), 201
    except Exception as e:
        db.session.rollback()
        print(f"ERROR: Exception occurred: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/events/<event_id>', methods=['PUT'])
def update_event(event_id):
    """Update an existing event."""
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    try:
        if 'title' in data:
            event.title = data['title']
        if 'type' in data:
            event.type = data['type']
        if 'location' in data:
            event.location = data['location']
        if 'date' in data:
            date_value = data['date']
            if isinstance(date_value, str):
                date_value = date_parser.parse(date_value)
            event.date = date_value
        if 'description' in data:
            event.description = data['description']
        if 'capacity' in data:
            event.capacity = data['capacity']
        if 'minimumAge' in data:
            event.minimum_age = data['minimumAge']
        if 'attendees' in data:
            attendees = data['attendees']
            if isinstance(attendees, list):
                attendees = ','.join(attendees)
            event.attendees = attendees

        db.session.commit()
        return jsonify(event.to_dict())
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/api/events/<event_id>', methods=['DELETE'])
def delete_event(event_id):
    """Delete an event."""
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    try:
        db.session.delete(event)
        db.session.commit()
        return jsonify({'message': 'Event deleted successfully'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@app.route('/api/events/<event_id>/rsvp', methods=['POST'])
def toggle_rsvp(event_id):
    """Toggle RSVP for a user on an event."""
    event = Event.query.get(event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    data = request.get_json()
    user_id = data.get('userId')
    if not user_id:
        return jsonify({'error': 'userId is required'}), 400

    attendee_list = [a.strip() for a in event.attendees.split(',') if a.strip()]

    if user_id in attendee_list:
        # Remove RSVP
        attendee_list.remove(user_id)
        action = 'removed'
    else:
        # Check capacity
        if event.capacity and len(attendee_list) >= event.capacity:
            return jsonify({'error': 'Event is full'}), 400
        attendee_list.append(user_id)
        action = 'added'

    event.attendees = ','.join(attendee_list)

    try:
        db.session.commit()
        return jsonify({
            'message': f'RSVP {action} successfully',
            'attending': action == 'added',
            'event': event.to_dict()
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("Starting Rural-Activities API server...")
    print("API available at http://localhost:5001")
    print("Endpoints:")
    print("  GET    /api/health           - Health check")
    print("  GET    /api/events           - List all events")
    print("  GET    /api/events/<id>      - Get event by ID")
    print("  POST   /api/events           - Create new event")
    print("  PUT    /api/events/<id>      - Update event")
    print("  DELETE /api/events/<id>      - Delete event")
    print("  POST   /api/events/<id>/rsvp - Toggle RSVP")
    app.run(host='0.0.0.0', port=5001, debug=True)
