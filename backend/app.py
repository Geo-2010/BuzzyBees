"""
BuzzyBees Flask API
A REST API for managing community events with JWT authentication.
"""

# ── DEPLOYMENT CHECKLIST ───────────────────────────────────────────────────────
# 1. HTTPS: Run behind a reverse proxy with TLS (nginx/caddy).
#    Never expose this HTTP server directly. Example Caddy config:
#      your-domain.com { reverse_proxy localhost:5001 }
#    Then update baseURL in APIService.swift to "https://your-domain.com"
#
# 2. JWT SECRET: Set JWT_SECRET_KEY environment variable before starting.
#    Generate a strong secret:  python3 -c "import secrets; print(secrets.token_hex(32))"
#    The app reads it via os.environ.get('JWT_SECRET_KEY') and falls back
#    to .jwt_secret file only if the env var is missing (dev convenience only).
#    In production, always use the env var. Never commit .jwt_secret to git.
# ──────────────────────────────────────────────────────────────────────────────

from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import (
    JWTManager, create_access_token, jwt_required, get_jwt_identity
)
from datetime import datetime, timezone, timedelta
from dateutil import parser as date_parser
import uuid
import os
import bcrypt
import logging

# Configure logging (replaces debug print statements)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# CORS: restrict to known origins. For the iOS app this is mostly irrelevant
# (mobile clients don't use CORS), but it prevents web-based API abuse.
# Add your production domain to ALLOWED_ORIGINS or set the CORS_ORIGINS env var.
# Format: comma-separated list, e.g. "https://yourdomain.com,https://app.yourdomain.com"
_cors_origins = os.environ.get('CORS_ORIGINS', 'http://localhost:3000,http://localhost:5173')
ALLOWED_ORIGINS = [o.strip() for o in _cors_origins.split(',') if o.strip()]
CORS(app, origins=ALLOWED_ORIGINS, supports_credentials=True)

# Request size limit (50 KB)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024

# JWT configuration — load or generate a stable secret key
def _load_jwt_secret() -> str:
    secret = os.environ.get('JWT_SECRET_KEY')
    if secret:
        return secret
    basedir = os.path.abspath(os.path.dirname(__file__))
    secret_file = os.path.join(basedir, '.jwt_secret')
    if os.path.exists(secret_file):
        with open(secret_file) as f:
            return f.read().strip()
    secret = os.urandom(32).hex()
    with open(secret_file, 'w') as f:
        f.write(secret)
    logger.info("Generated new JWT secret key and saved to .jwt_secret")
    return secret

app.config['JWT_SECRET_KEY'] = _load_jwt_secret()
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=30)
jwt = JWTManager(app)

# Rate limiter (keyed by client IP)
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per minute"],
    storage_uri="memory://",
)

# Configure SQLite database
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(basedir, "events.db")}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

VALID_TYPES = ['Sports', 'Party', 'Study Group', 'Meeting', 'Outdoor']
VALID_MIN_AGES = [18, 21, 25]


class User(db.Model):
    """User model for authentication."""
    __tablename__ = 'users'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(200), unique=True, nullable=False)
    display_name = db.Column(db.String(100), nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # Feature 6: Plus-One tokens
    plus_ones_remaining = db.Column(db.Integer, default=3)
    plus_ones_reset_date = db.Column(db.DateTime, nullable=True)

    def set_password(self, password: str):
        self.password_hash = bcrypt.hashpw(
            password.encode('utf-8'), bcrypt.gensalt()
        ).decode('utf-8')

    def check_password(self, password: str) -> bool:
        return bcrypt.checkpw(
            password.encode('utf-8'),
            self.password_hash.encode('utf-8')
        )


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
    waitlist = db.Column(db.Text, default='')  # Comma-separated emails on waitlist
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    # Feature 1: Swarm Mode
    swarm_mode = db.Column(db.Boolean, default=False)
    swarm_min_attendees = db.Column(db.Integer, nullable=True)
    swarm_deadline = db.Column(db.DateTime, nullable=True)

    # Feature 2: Blind Location
    location_hidden = db.Column(db.Boolean, default=False)
    location_reveal_threshold = db.Column(db.Integer, nullable=True)

    # Feature 3: RSVP timestamp log for momentum (JSON array of ISO8601 strings, newest first, max 50)
    rsvp_log = db.Column(db.Text, default='[]')

    # Feature 4: En Route
    en_route_users = db.Column(db.Text, default='')  # CSV emails
    arrived_users = db.Column(db.Text, default='')   # CSV emails

    # Feature 5: Echoes (JSON array of {email, tag, ts})
    echoes = db.Column(db.Text, default='[]')

    # Feature 6: Plus-One guests (JSON array of {inviterEmail, guestName, ts})
    plus_one_guests = db.Column(db.Text, default='[]')

    def to_dict(self, requester=None):
        """Convert event to dictionary for JSON response."""
        attendee_list = [a.strip() for a in (self.attendees or '').split(',') if a.strip()]
        waitlist_list = [w.strip() for w in (self.waitlist or '').split(',') if w.strip()]
        en_route_list = [u.strip() for u in (self.en_route_users or '').split(',') if u.strip()]
        arrived_list = [u.strip() for u in (self.arrived_users or '').split(',') if u.strip()]

        # Parse JSON fields safely
        import json as _json
        def safe_json(text, default):
            try:
                return _json.loads(text or '[]')
            except Exception:
                return default

        echoes_data = safe_json(self.echoes, [])
        plus_one_data = safe_json(self.plus_one_guests, [])
        rsvp_log_data = safe_json(self.rsvp_log, [])

        # Compute buzz score: RSVPs in the last 2 hours
        two_hours_ago = datetime.now(timezone.utc) - timedelta(hours=2)
        buzz_score = sum(
            1 for ts in rsvp_log_data
            if _parse_ts(ts) and _parse_ts(ts) > two_hours_ago
        )

        # Location masking for blind reveal
        is_creator = requester and requester == self.user_id
        threshold_met = (
            self.location_reveal_threshold is None or
            len(attendee_list) >= self.location_reveal_threshold
        )
        if self.location_hidden and not threshold_met and not is_creator:
            display_location = f"Hidden · {self.location_reveal_threshold - len(attendee_list)} more RSVPs to unlock"
            location_unlocked = False
        else:
            display_location = self.location
            location_unlocked = True

        date_str = self.date.strftime('%Y-%m-%dT%H:%M:%SZ')
        created_str = (
            self.created_at.strftime('%Y-%m-%dT%H:%M:%SZ')
            if self.created_at else date_str
        )
        swarm_deadline_str = (
            self.swarm_deadline.strftime('%Y-%m-%dT%H:%M:%SZ')
            if self.swarm_deadline else None
        )

        return {
            'id': self.id,
            'title': self.title,
            'type': self.type,
            'location': display_location,
            'locationUnlocked': location_unlocked,
            'date': date_str,
            'createdAt': created_str,
            'description': self.description,
            'userId': self.user_id,
            'capacity': self.capacity,
            'minimumAge': self.minimum_age,
            'attendees': attendee_list,
            'waitlist': waitlist_list,
            # Feature 1: Swarm
            'swarmMode': bool(self.swarm_mode),
            'swarmMinAttendees': self.swarm_min_attendees,
            'swarmDeadline': swarm_deadline_str,
            # Feature 2: Blind location
            'locationHidden': bool(self.location_hidden),
            'locationRevealThreshold': self.location_reveal_threshold,
            # Feature 3: Buzz
            'buzzScore': buzz_score,
            # Feature 4: En Route
            'enRouteUsers': en_route_list,
            'arrivedUsers': arrived_list,
            # Feature 5: Echoes
            'echoes': echoes_data,
            # Feature 6: Plus-ones
            'plusOneGuests': plus_one_data,
            'latitude': self.latitude,
            'longitude': self.longitude,
        }

    @staticmethod
    def from_dict(data, owner_id: str):
        """Create Event from dictionary. owner_id is always the verified JWT identity."""
        # Accept client-supplied UUID (UUIDs are 122-bit random, collision is negligible)
        # but validate the format
        raw_id = data.get('id', '')
        try:
            event_id = str(uuid.UUID(raw_id)) if raw_id else str(uuid.uuid4())
        except ValueError:
            event_id = str(uuid.uuid4())

        attendees = data.get('attendees', [])
        if isinstance(attendees, list):
            attendees = ','.join(attendees)

        date_value = data.get('date')
        if isinstance(date_value, str):
            date_value = date_parser.parse(date_value)

        swarm_deadline_val = None
        if data.get('swarmDeadline'):
            try:
                swarm_deadline_val = date_parser.parse(data['swarmDeadline'])
            except Exception:
                pass

        return Event(
            id=event_id,
            title=data['title'].strip(),
            type=data['type'],
            location=data['location'].strip(),
            date=date_value,
            description=data['description'],
            user_id=owner_id,  # Always use JWT identity, never trust client-supplied userId
            capacity=data.get('capacity'),
            minimum_age=data.get('minimumAge'),
            attendees=attendees,
            latitude=data.get('latitude'),
            longitude=data.get('longitude'),
            created_at=datetime.now(timezone.utc),
            swarm_mode=bool(data.get('swarmMode', False)),
            swarm_min_attendees=data.get('swarmMinAttendees'),
            swarm_deadline=swarm_deadline_val,
            location_hidden=bool(data.get('locationHidden', False)),
            location_reveal_threshold=data.get('locationRevealThreshold'),
        )


# ── Helper: ISO8601 timestamp parser ──────────────────────────────────────────

def _parse_ts(ts_str):
    """Parse ISO8601 timestamp string to datetime, returns None on failure."""
    try:
        dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


# Create tables and run lightweight migrations
with app.app_context():
    db.create_all()
    # Migration: add created_at to existing events table if the column is missing
    with db.engine.connect() as conn:
        try:
            conn.execute(db.text(
                "ALTER TABLE events ADD COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP"
            ))
            conn.commit()
            logger.info("Migration: added created_at column to events table")
        except Exception:
            pass  # Column already exists
        try:
            conn.execute(db.text(
                "ALTER TABLE events ADD COLUMN waitlist TEXT DEFAULT ''"
            ))
            conn.commit()
            logger.info("Migration: added waitlist column to events table")
        except Exception:
            pass  # Column already exists

        # Features 1-6: new event columns
        new_event_cols = [
            ("swarm_mode", "BOOLEAN DEFAULT 0"),
            ("swarm_min_attendees", "INTEGER"),
            ("swarm_deadline", "DATETIME"),
            ("location_hidden", "BOOLEAN DEFAULT 0"),
            ("location_reveal_threshold", "INTEGER"),
            ("rsvp_log", "TEXT DEFAULT '[]'"),
            ("en_route_users", "TEXT DEFAULT ''"),
            ("arrived_users", "TEXT DEFAULT ''"),
            ("echoes", "TEXT DEFAULT '[]'"),
            ("plus_one_guests", "TEXT DEFAULT '[]'"),
        ]
        for col_name, col_def in new_event_cols:
            try:
                conn.execute(db.text(f"ALTER TABLE events ADD COLUMN {col_name} {col_def}"))
                conn.commit()
            except Exception:
                pass

        # Feature 6: new user columns
        new_user_cols = [
            ("plus_ones_remaining", "INTEGER DEFAULT 3"),
            ("plus_ones_reset_date", "DATETIME"),
        ]
        for col_name, col_def in new_user_cols:
            try:
                conn.execute(db.text(f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"))
                conn.commit()
            except Exception:
                pass


# ── Error handlers ─────────────────────────────────────────────────────────────

@app.errorhandler(413)
def request_entity_too_large(e):
    return jsonify({'error': 'Request payload exceeds 50 KB limit'}), 413


@app.errorhandler(429)
def ratelimit_handler(e):
    return jsonify({'error': 'Rate limit exceeded', 'message': str(e.description)}), 429


# ── Auth Routes ────────────────────────────────────────────────────────────────

@app.route('/api/auth/register', methods=['POST'])
@limiter.limit("10 per minute")
def register():
    """Register a new user account."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    required = ['email', 'password', 'displayName']
    missing = [f for f in required if not str(data.get(f, '')).strip()]
    if missing:
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    email = data.get('email', '').lower().strip()
    password = data['password']
    display_name = data['displayName'].strip()

    if '@' not in email or '.' not in email.split('@')[-1]:
        return jsonify({'error': 'Invalid email address'}), 400

    if len(password) < 6:
        return jsonify({'error': 'Password must be at least 6 characters'}), 400

    if len(display_name) < 2:
        return jsonify({'error': 'Display name must be at least 2 characters'}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'An account with this email already exists'}), 409

    user = User(email=email, display_name=display_name)
    user.set_password(password)

    try:
        db.session.add(user)
        db.session.commit()
        token = create_access_token(identity=email)
        logger.info(f"New user registered: {email}")
        return jsonify({'token': token, 'displayName': display_name}), 201
    except Exception as e:
        db.session.rollback()
        logger.error(f"Registration error: {e}")
        return jsonify({'error': 'Registration failed'}), 500


@app.route('/api/auth/login', methods=['POST'])
@limiter.limit("20 per minute")
def login():
    """Authenticate a user and return a JWT token."""
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    email = data.get('email', '').strip().lower()
    password = data.get('password', '')

    if not email or not password:
        return jsonify({'error': 'Email and password are required'}), 400

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({'error': 'Invalid email or password'}), 401

    token = create_access_token(identity=email)
    logger.info(f"User logged in: {email}")
    return jsonify({'token': token, 'displayName': user.display_name})


# ── Event Routes ───────────────────────────────────────────────────────────────

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'ok', 'message': 'BuzzyBees API is running'})


@app.route('/api/events', methods=['GET'])
def get_events():
    """Get events with pagination."""
    # Try to get requester identity (optional auth)
    requester = None
    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(optional=True)
        requester = get_jwt_identity()
    except Exception:
        pass

    echo_window = datetime.now(timezone.utc) - timedelta(hours=48)

    # Delete evaporated swarm events (deadline passed, threshold not met)
    swarm_evaporated = Event.query.filter(
        Event.swarm_mode == True,
        Event.swarm_deadline < datetime.now(timezone.utc),
    ).all()
    for ev in swarm_evaporated:
        attendee_list = [a.strip() for a in (ev.attendees or '').split(',') if a.strip()]
        if len(attendee_list) < (ev.swarm_min_attendees or 1):
            db.session.delete(ev)

    # Delete regular past events after 48h echo window
    past_deleted = Event.query.filter(Event.date < echo_window).delete()
    if past_deleted or swarm_evaporated:
        db.session.commit()

    user_id = request.args.get('userId')
    event_type = request.args.get('type')
    location = request.args.get('location')
    page = request.args.get('page', 1, type=int)
    per_page = min(request.args.get('per_page', 20, type=int), 100)

    query = Event.query

    if user_id:
        query = query.filter_by(user_id=user_id)
    if event_type:
        if event_type not in VALID_TYPES:
            return jsonify({'error': 'Invalid event type'}), 400
        query = query.filter_by(type=event_type)
    if location:
        query = query.filter(Event.location.ilike(f'%{location}%'))

    query = query.order_by(Event.date.asc())

    total = query.count()
    events = query.offset((page - 1) * per_page).limit(per_page).all()

    return jsonify({
        'events': [e.to_dict(requester=requester) for e in events],
        'total': total,
        'page': page,
        'perPage': per_page,
    })


@app.route('/api/events/<event_id>', methods=['GET'])
def get_event(event_id):
    """Get a single event by ID."""
    requester = None
    try:
        from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity
        verify_jwt_in_request(optional=True)
        requester = get_jwt_identity()
    except Exception:
        pass

    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404
    return jsonify(event.to_dict(requester=requester))


@app.route('/api/events', methods=['POST'])
@jwt_required()
@limiter.limit("20 per minute")
def create_event():
    """Create a new event. Requires authentication."""
    current_user = get_jwt_identity()

    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    required_fields = ['title', 'type', 'location', 'date', 'description']
    missing = [f for f in required_fields if not data.get(f)]
    if missing:
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    if data['type'] not in VALID_TYPES:
        return jsonify({'error': f'Invalid event type. Must be one of: {", ".join(VALID_TYPES)}'}), 400

    if len(data['title'].strip()) > 60:
        return jsonify({'error': 'Title must be 60 characters or less'}), 400

    description = data.get('description', '')
    if len(description.strip()) < 10:
        return jsonify({'error': 'Description must be at least 10 characters'}), 400
    if len(description) > 2000:
        return jsonify({'error': 'Description must be 2000 characters or less'}), 400

    # Server-side events-per-day limit (mirrors the frontend 5/day cap)
    today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    events_today = Event.query.filter(
        Event.user_id == current_user,
        Event.created_at >= today_start,
    ).count()
    if events_today >= 5:
        return jsonify({'error': 'Daily event limit reached. You can create up to 5 events per day.'}), 429

    capacity = data.get('capacity')
    if capacity is not None:
        if not isinstance(capacity, int) or capacity < 2 or capacity > 500:
            return jsonify({'error': 'Capacity must be between 2 and 500'}), 400

    minimum_age = data.get('minimumAge')
    if minimum_age is not None and minimum_age not in VALID_MIN_AGES:
        return jsonify({'error': f'Minimum age must be one of: {VALID_MIN_AGES}'}), 400

    # Feature 1: Swarm mode
    swarm_mode = bool(data.get('swarmMode', False))
    swarm_min = data.get('swarmMinAttendees')
    swarm_deadline = data.get('swarmDeadline')
    if swarm_mode:
        if not swarm_min or not isinstance(swarm_min, int) or swarm_min < 2:
            return jsonify({'error': 'Swarm events require swarmMinAttendees >= 2'}), 400
        if not swarm_deadline:
            return jsonify({'error': 'Swarm events require a swarmDeadline'}), 400

    # Feature 2: Blind location
    location_hidden = bool(data.get('locationHidden', False))
    location_reveal_threshold = data.get('locationRevealThreshold')
    if location_hidden and (not location_reveal_threshold or not isinstance(location_reveal_threshold, int) or location_reveal_threshold < 1):
        return jsonify({'error': 'Hidden location events require locationRevealThreshold >= 1'}), 400

    try:
        event = Event.from_dict(data, owner_id=current_user)
        db.session.add(event)
        db.session.commit()
        logger.info(f"Event created: {event.id} by {current_user}")
        return jsonify(event.to_dict(requester=current_user)), 201
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to create event: {e}")
        return jsonify({'error': 'Failed to create event'}), 500


@app.route('/api/events/<event_id>', methods=['PUT'])
@jwt_required()
@limiter.limit("20 per minute")
def update_event(event_id):
    """Update an existing event. Only the verified creator can update."""
    current_user = get_jwt_identity()

    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    if event.user_id != current_user:
        return jsonify({'error': 'Only the event creator can update this event'}), 403

    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    if 'title' in data and (not data['title'] or not data['title'].strip()):
        return jsonify({'error': 'Title cannot be empty'}), 400
    if 'title' in data and len(data['title'].strip()) > 60:
        return jsonify({'error': 'Title must be 60 characters or less'}), 400
    if 'type' in data and data['type'] not in VALID_TYPES:
        return jsonify({'error': f'Invalid event type. Must be one of: {", ".join(VALID_TYPES)}'}), 400
    if 'location' in data and (not data['location'] or not data['location'].strip()):
        return jsonify({'error': 'Location cannot be empty'}), 400
    if 'description' in data:
        desc = data['description']
        if len(desc.strip()) < 10:
            return jsonify({'error': 'Description must be at least 10 characters'}), 400
        if len(desc) > 2000:
            return jsonify({'error': 'Description must be 2000 characters or less'}), 400
    if 'capacity' in data and data['capacity'] is not None:
        if not isinstance(data['capacity'], int) or data['capacity'] < 2 or data['capacity'] > 500:
            return jsonify({'error': 'Capacity must be between 2 and 500'}), 400
    if 'minimumAge' in data and data['minimumAge'] is not None:
        if data['minimumAge'] not in VALID_MIN_AGES:
            return jsonify({'error': f'Minimum age must be one of: {VALID_MIN_AGES}'}), 400

    try:
        if 'title' in data:
            event.title = data['title'].strip()
        if 'type' in data:
            event.type = data['type']
        if 'location' in data:
            event.location = data['location'].strip()
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
        if 'latitude' in data:
            event.latitude = data['latitude']
        if 'longitude' in data:
            event.longitude = data['longitude']
        # Feature 1: Swarm Mode updates
        if 'swarmMode' in data:
            event.swarm_mode = bool(data['swarmMode'])
        if 'swarmMinAttendees' in data:
            event.swarm_min_attendees = data['swarmMinAttendees']
        if 'swarmDeadline' in data and data['swarmDeadline']:
            try:
                event.swarm_deadline = date_parser.parse(data['swarmDeadline'])
            except Exception:
                pass
        # Feature 2: Blind location updates
        if 'locationHidden' in data:
            event.location_hidden = bool(data['locationHidden'])
        if 'locationRevealThreshold' in data:
            event.location_reveal_threshold = data['locationRevealThreshold']

        db.session.commit()
        return jsonify(event.to_dict(requester=current_user))
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to update event {event_id}: {e}")
        return jsonify({'error': 'Failed to update event'}), 500


@app.route('/api/events/<event_id>', methods=['DELETE'])
@jwt_required()
@limiter.limit("20 per minute")
def delete_event(event_id):
    """Delete an event. Only the verified creator can delete."""
    current_user = get_jwt_identity()

    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    if event.user_id != current_user:
        return jsonify({'error': 'Only the event creator can delete this event'}), 403

    try:
        db.session.delete(event)
        db.session.commit()
        logger.info(f"Event deleted: {event_id} by {current_user}")
        return jsonify({'message': 'Event deleted successfully'})
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to delete event {event_id}: {e}")
        return jsonify({'error': 'Failed to delete event'}), 500


@app.route('/api/events/<event_id>/rsvp', methods=['POST'])
@jwt_required()
@limiter.limit("30 per minute")
def toggle_rsvp(event_id):
    """Toggle RSVP for the authenticated user on an event."""
    import json as _json
    current_user = get_jwt_identity()

    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    attendee_list = [a.strip() for a in (event.attendees or '').split(',') if a.strip()]
    waitlist = [w.strip() for w in (event.waitlist or '').split(',') if w.strip()]

    if current_user in attendee_list:
        attendee_list.remove(current_user)
        action = 'removed'
        # Auto-promote first waitlisted person when a spot opens
        if waitlist and (event.capacity is None or len(attendee_list) < event.capacity):
            promoted = waitlist.pop(0)
            attendee_list.append(promoted)
            event.waitlist = ','.join(waitlist)
            logger.info(f"Promoted {promoted} from waitlist for event {event_id}")
    elif current_user in waitlist:
        # Already on waitlist — remove (toggle off)
        waitlist.remove(current_user)
        event.waitlist = ','.join(waitlist)
        action = 'waitlist_removed'
    else:
        if event.capacity and len(attendee_list) >= event.capacity:
            return jsonify({'error': 'Event is full'}), 400
        attendee_list.append(current_user)
        action = 'added'

    event.attendees = ','.join(attendee_list)

    # Feature 3: Append timestamp to rsvp_log for momentum tracking (only on add, not remove)
    if action == 'added':
        log = []
        try:
            log = _json.loads(event.rsvp_log or '[]')
        except Exception:
            pass
        log.insert(0, datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
        event.rsvp_log = _json.dumps(log[:50])  # keep last 50

    try:
        db.session.commit()
        return jsonify({
            'message': f'RSVP {action} successfully',
            'attending': action == 'added',
            'event': event.to_dict(requester=current_user),
        })
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to toggle RSVP for event {event_id}: {e}")
        return jsonify({'error': 'Failed to update RSVP'}), 500


@app.route('/api/events/<event_id>/waitlist', methods=['POST'])
@jwt_required()
@limiter.limit("30 per minute")
def toggle_waitlist(event_id):
    """Toggle waitlist for the authenticated user. Only valid when event is full."""
    current_user = get_jwt_identity()

    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    attendee_list = [a.strip() for a in (event.attendees or '').split(',') if a.strip()]
    waitlist = [w.strip() for w in (event.waitlist or '').split(',') if w.strip()]

    if current_user in attendee_list:
        return jsonify({'error': 'You are already attending this event'}), 400

    if current_user in waitlist:
        waitlist.remove(current_user)
        on_waitlist = False
    else:
        if event.capacity and len(attendee_list) < event.capacity:
            return jsonify({'error': 'Event is not full — use RSVP instead'}), 400
        if current_user in waitlist:
            return jsonify({'error': 'Already on waitlist'}), 400
        waitlist.append(current_user)
        on_waitlist = True

    event.waitlist = ','.join(waitlist)

    try:
        db.session.commit()
        return jsonify({
            'message': 'Waitlist updated',
            'onWaitlist': on_waitlist,
            'position': waitlist.index(current_user) + 1 if on_waitlist else None,
            'event': event.to_dict(requester=current_user),
        })
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to toggle waitlist for event {event_id}: {e}")
        return jsonify({'error': 'Failed to update waitlist'}), 500


@app.route('/api/auth/profile', methods=['PUT'])
@jwt_required()
@limiter.limit("10 per minute")
def update_profile():
    """Update the authenticated user's display name."""
    current_user = get_jwt_identity()
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    display_name = data.get('displayName', '').strip()
    if len(display_name) < 2:
        return jsonify({'error': 'Display name must be at least 2 characters'}), 400
    if len(display_name) > 100:
        return jsonify({'error': 'Display name must be 100 characters or less'}), 400

    user = User.query.filter_by(email=current_user).first()
    if not user:
        return jsonify({'error': 'User not found'}), 404

    try:
        user.display_name = display_name
        db.session.commit()
        logger.info(f"Profile updated for {current_user}")
        return jsonify({'displayName': display_name})
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to update profile: {e}")
        return jsonify({'error': 'Failed to update profile'}), 500


# ── Feature 4: En Route Status ─────────────────────────────────────────────────

@app.route('/api/events/<event_id>/status', methods=['POST'])
@jwt_required()
@limiter.limit("30 per minute")
def update_travel_status(event_id):
    """Update travel status: en_route, arrived, or none."""
    current_user = get_jwt_identity()
    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    data = request.get_json() or {}
    status = data.get('status', 'none')
    if status not in ('en_route', 'arrived', 'none'):
        return jsonify({'error': 'status must be en_route, arrived, or none'}), 400

    en_route = [u.strip() for u in (event.en_route_users or '').split(',') if u.strip()]
    arrived = [u.strip() for u in (event.arrived_users or '').split(',') if u.strip()]

    # Remove from both lists first
    en_route = [u for u in en_route if u != current_user]
    arrived = [u for u in arrived if u != current_user]

    if status == 'en_route':
        en_route.append(current_user)
    elif status == 'arrived':
        arrived.append(current_user)

    event.en_route_users = ','.join(en_route)
    event.arrived_users = ','.join(arrived)

    try:
        db.session.commit()
        return jsonify({'status': status, 'event': event.to_dict(requester=current_user)})
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to update status: {e}")
        return jsonify({'error': 'Failed to update status'}), 500


# ── Feature 5: Post-Event Echoes ───────────────────────────────────────────────

@app.route('/api/events/<event_id>/echo', methods=['POST'])
@jwt_required()
@limiter.limit("10 per minute")
def post_echo(event_id):
    """Post a vibe echo for a past event. Only attendees can echo, within 48h."""
    import json as _json
    current_user = get_jwt_identity()
    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    # Must be in the past
    if event.date >= datetime.now(timezone.utc):
        return jsonify({'error': 'Echoes can only be left after the event has passed'}), 400

    # Must be within 48h
    echo_deadline = event.date + timedelta(hours=48)
    if datetime.now(timezone.utc) > echo_deadline:
        return jsonify({'error': 'Echo window has closed (48 hours after event)'}), 400

    attendee_list = [a.strip() for a in (event.attendees or '').split(',') if a.strip()]
    if current_user not in attendee_list:
        return jsonify({'error': 'Only attendees can leave echoes'}), 403

    data = request.get_json() or {}
    tag = data.get('tag', '').strip()
    if not tag or len(tag) > 30:
        return jsonify({'error': 'Echo tag must be 1–30 characters'}), 400

    try:
        echoes = _json.loads(event.echoes or '[]')
    except Exception:
        echoes = []

    # One echo per user per event
    echoes = [e for e in echoes if e.get('email') != current_user]
    echoes.append({
        'email': current_user,
        'tag': tag,
        'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    })
    event.echoes = _json.dumps(echoes)

    try:
        db.session.commit()
        return jsonify({'message': 'Echo posted', 'echoes': echoes})
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to post echo: {e}")
        return jsonify({'error': 'Failed to post echo'}), 500


# ── Feature 6: Plus-One Tokens ────────────────────────────────────────────────

@app.route('/api/events/<event_id>/plus_one', methods=['POST'])
@jwt_required()
@limiter.limit("10 per minute")
def add_plus_one(event_id):
    """Spend a Plus-One token to add a named guest to an event."""
    import json as _json
    current_user = get_jwt_identity()
    event = db.session.get(Event, event_id)
    if not event:
        return jsonify({'error': 'Event not found'}), 404

    attendee_list = [a.strip() for a in (event.attendees or '').split(',') if a.strip()]
    if current_user not in attendee_list:
        return jsonify({'error': 'You must be attending to bring a guest'}), 403

    user = User.query.filter_by(email=current_user).first()
    if not user:
        return jsonify({'error': 'User not found'}), 404

    # Reset tokens on the 1st of each month
    now = datetime.now(timezone.utc)
    if user.plus_ones_reset_date is None or user.plus_ones_reset_date.month != now.month or user.plus_ones_reset_date.year != now.year:
        user.plus_ones_remaining = 3
        user.plus_ones_reset_date = now

    if user.plus_ones_remaining <= 0:
        return jsonify({'error': 'No Plus-One tokens remaining this month'}), 400

    data = request.get_json() or {}
    guest_name = data.get('guestName', '').strip()
    if not guest_name or len(guest_name) > 60:
        return jsonify({'error': 'Guest name must be 1–60 characters'}), 400

    try:
        guests = _json.loads(event.plus_one_guests or '[]')
    except Exception:
        guests = []

    guests.append({
        'inviterEmail': current_user,
        'guestName': guest_name,
        'ts': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
    })
    event.plus_one_guests = _json.dumps(guests)
    user.plus_ones_remaining -= 1

    try:
        db.session.commit()
        return jsonify({
            'message': 'Guest added',
            'plusOnesRemaining': user.plus_ones_remaining,
            'event': event.to_dict(requester=current_user),
        })
    except Exception as e:
        db.session.rollback()
        logger.error(f"Failed to add plus-one: {e}")
        return jsonify({'error': 'Failed to add guest'}), 500


@app.route('/api/auth/plus_ones', methods=['GET'])
@jwt_required()
def get_plus_ones():
    """Get current user's Plus-One token count."""
    current_user = get_jwt_identity()
    user = User.query.filter_by(email=current_user).first()
    if not user:
        return jsonify({'error': 'User not found'}), 404

    now = datetime.now(timezone.utc)
    if user.plus_ones_reset_date is None or user.plus_ones_reset_date.month != now.month:
        user.plus_ones_remaining = 3
        user.plus_ones_reset_date = now
        db.session.commit()

    return jsonify({'plusOnesRemaining': user.plus_ones_remaining})


if __name__ == '__main__':
    # NOTE: Use HTTPS in production. Run behind a reverse proxy (nginx/caddy)
    # with a valid TLS certificate. Never expose this HTTP server directly.
    app.run(host='0.0.0.0', port=5001, debug=False)
