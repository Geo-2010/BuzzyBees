/**
 * Rural-Activities Node.js API
 * A lightweight REST API for managing community events.
 */

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { Sequelize, DataTypes } = require('sequelize');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5001;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50kb' })); // Request size limit (50 KB)

// Rate limiter (keyed by client IP)
const defaultLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 200,
  message: { error: 'Rate limit exceeded' }
});

const strictLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 20,
  message: { error: 'Rate limit exceeded' }
});

const rsvpLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 30,
  message: { error: 'Rate limit exceeded' }
});

app.use(defaultLimiter);

// Configure SQLite database
const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: path.join(__dirname, 'events.db'),
  logging: false
});

// Event model matching the iOS app's Event struct
const Event = sequelize.define('Event', {
  id: {
    type: DataTypes.STRING(36),
    primaryKey: true,
    defaultValue: () => uuidv4()
  },
  title: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  type: {
    type: DataTypes.STRING(50),
    allowNull: false
  },
  location: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  date: {
    type: DataTypes.DATE,
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  user_id: {
    type: DataTypes.STRING(200),
    allowNull: false
  },
  capacity: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  minimum_age: {
    type: DataTypes.INTEGER,
    allowNull: true
  },
  attendees: {
    type: DataTypes.TEXT,
    defaultValue: ''
  }
}, {
  tableName: 'events',
  timestamps: false
});

// Helper methods
Event.prototype.toJSON = function() {
  const values = { ...this.get() };
  const attendeeList = values.attendees
    ? values.attendees.split(',').map(a => a.trim()).filter(a => a)
    : [];

  // Format date as ISO8601 with Z suffix for iOS compatibility
  const dateStr = new Date(values.date).toISOString().replace(/\.\d{3}Z$/, 'Z');

  return {
    id: values.id,
    title: values.title,
    type: values.type,
    location: values.location,
    date: dateStr,
    description: values.description,
    userId: values.user_id,
    capacity: values.capacity,
    minimumAge: values.minimum_age,
    attendees: attendeeList
  };
};

// Initialize database
sequelize.sync().then(() => {
  console.log('Database synchronized');
});

// Error handlers
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Request payload exceeds 50 KB limit' });
  }
  next(err);
});

// API Routes

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Rural-Activities API is running' });
});

app.get('/api/events', async (req, res) => {
  try {
    console.log('\n' + '-'.repeat(50));
    console.log('GET /api/events - Fetching events');

    const { userId, type, location } = req.query;
    console.log(`  Filters: userId=${userId}, type=${type}, location=${location}`);

    const where = {};
    if (userId) where.user_id = userId;
    if (type) where.type = type;
    if (location) {
      where.location = { [Sequelize.Op.like]: `%${location}%` };
    }

    const events = await Event.findAll({
      where,
      order: [['date', 'ASC']]
    });

    console.log(`  Returning ${events.length} events`);
    events.forEach(e => {
      console.log(`    - ${e.title} (${e.id})`);
    });
    console.log('-'.repeat(50) + '\n');

    res.json({ events: events.map(e => e.toJSON()) });
  } catch (error) {
    console.error('Error fetching events:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/events/:eventId', async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }
    res.json(event.toJSON());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/events', strictLimiter, async (req, res) => {
  try {
    console.log('\n' + '='.repeat(50));
    console.log('POST /api/events - Creating new event');
    console.log('='.repeat(50));

    const data = req.body;
    console.log('Received data:', data);

    if (!data) {
      console.log('ERROR: No data provided');
      return res.status(400).json({ error: 'No data provided' });
    }

    const requiredFields = ['title', 'type', 'location', 'date', 'description', 'userId'];
    const missing = requiredFields.filter(f => !(f in data));
    if (missing.length > 0) {
      console.log(`ERROR: Missing fields: ${missing}`);
      return res.status(400).json({ error: `Missing required fields: ${missing.join(', ')}` });
    }

    // Validate event type
    const validTypes = ['Sports', 'Party', 'Study Group', 'Meeting'];
    if (!validTypes.includes(data.type)) {
      console.log(`ERROR: Invalid event type: ${data.type}`);
      return res.status(400).json({
        error: `Invalid event type. Must be one of: ${validTypes.join(', ')}`
      });
    }

    const attendees = Array.isArray(data.attendees) ? data.attendees.join(',') : '';

    const event = await Event.create({
      id: data.id || uuidv4(),
      title: data.title,
      type: data.type,
      location: data.location,
      date: new Date(data.date),
      description: data.description,
      user_id: data.userId,
      capacity: data.capacity,
      minimum_age: data.minimumAge,
      attendees: attendees
    });

    console.log(`SUCCESS: Event created with ID: ${event.id}`);
    console.log(`  Title: ${event.title}`);
    console.log(`  Type: ${event.type}`);
    console.log(`  Date: ${event.date}`);
    console.log(`  User: ${event.user_id}`);
    console.log('='.repeat(50) + '\n');

    res.status(201).json(event.toJSON());
  } catch (error) {
    console.error(`ERROR: Exception occurred: ${error.message}`);
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/events/:eventId', strictLimiter, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const data = req.body;
    if (!data) {
      return res.status(400).json({ error: 'No data provided' });
    }

    if (data.title !== undefined) event.title = data.title;
    if (data.type !== undefined) event.type = data.type;
    if (data.location !== undefined) event.location = data.location;
    if (data.date !== undefined) event.date = new Date(data.date);
    if (data.description !== undefined) event.description = data.description;
    if (data.capacity !== undefined) event.capacity = data.capacity;
    if (data.minimumAge !== undefined) event.minimum_age = data.minimumAge;
    if (data.attendees !== undefined) {
      event.attendees = Array.isArray(data.attendees) ? data.attendees.join(',') : data.attendees;
    }

    await event.save();
    res.json(event.toJSON());
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/events/:eventId', strictLimiter, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    await event.destroy();
    res.json({ message: 'Event deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/events/:eventId/rsvp', rsvpLimiter, async (req, res) => {
  try {
    const event = await Event.findByPk(req.params.eventId);
    if (!event) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    let attendeeList = event.attendees
      ? event.attendees.split(',').map(a => a.trim()).filter(a => a)
      : [];

    let action;
    if (attendeeList.includes(userId)) {
      // Remove RSVP
      attendeeList = attendeeList.filter(a => a !== userId);
      action = 'removed';
    } else {
      // Check capacity
      if (event.capacity && attendeeList.length >= event.capacity) {
        return res.status(400).json({ error: 'Event is full' });
      }
      attendeeList.push(userId);
      action = 'added';
    }

    event.attendees = attendeeList.join(',');
    await event.save();

    res.json({
      message: `RSVP ${action} successfully`,
      attending: action === 'added',
      event: event.toJSON()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('Starting Rural-Activities API server...');
  console.log(`API available at http://localhost:${PORT}`);
  console.log('Endpoints:');
  console.log('  GET    /api/health           - Health check');
  console.log('  GET    /api/events           - List all events');
  console.log('  GET    /api/events/<id>      - Get event by ID');
  console.log('  POST   /api/events           - Create new event');
  console.log('  PUT    /api/events/<id>      - Update event');
  console.log('  DELETE /api/events/<id>      - Delete event');
  console.log('  POST   /api/events/<id>/rsvp - Toggle RSVP');
});
