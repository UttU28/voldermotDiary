const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

// Ensure data directory exists
const dataDir = path.join(__dirname, 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

// Initialize database
const dbPath = path.join(dataDir, 'voldermot_diary.db');
const db = new Database(dbPath);

// Enable WAL mode for better concurrency
db.pragma('journal_mode = WAL');

// Create tables
db.exec(`
  CREATE TABLE IF NOT EXISTS strokes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    socket_id TEXT,
    points TEXT NOT NULL,
    color TEXT NOT NULL,
    width REAL NOT NULL,
    created_at INTEGER NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS rooms (
    room_id TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL,
    last_activity INTEGER NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_strokes_room ON strokes(room_id);
  CREATE INDEX IF NOT EXISTS idx_strokes_created ON strokes(created_at);
`);

// Database operations
const dbOperations = {
  // Save a stroke to database
  saveStroke: (strokeData) => {
    const stmt = db.prepare(`
      INSERT INTO strokes (room_id, user_id, socket_id, points, color, width, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
      strokeData.roomId,
      strokeData.userId,
      strokeData.socketId || null,
      JSON.stringify(strokeData.points),
      strokeData.color,
      strokeData.width,
      strokeData.createdAt
    );
    
    return result.lastInsertRowid;
  },

  // Get all strokes for a room
  getStrokesForRoom: (roomId) => {
    try {
      const stmt = db.prepare(`
        SELECT * FROM strokes 
        WHERE room_id = ? 
        ORDER BY created_at ASC
      `);
      
      const rows = stmt.all(roomId);
      return rows.map(row => {
        const points = JSON.parse(row.points);
        return {
          id: row.id,
          userId: row.user_id,
          roomId: row.room_id,
          socketId: row.socket_id,
          points: points,
          color: row.color,
          width: row.width,
          createdAt: row.created_at,
        };
      });
    } catch (error) {
      console.error('Error loading strokes from database:', error);
      return [];
    }
  },

  // Clear all strokes for a room
  clearRoom: (roomId) => {
    const stmt = db.prepare('DELETE FROM strokes WHERE room_id = ?');
    const result = stmt.run(roomId);
    return result.changes;
  },

  // Delete a specific stroke
  deleteStroke: (roomId, userId, createdAt) => {
    const stmt = db.prepare(`
      DELETE FROM strokes 
      WHERE room_id = ? AND user_id = ? AND created_at = ?
    `);
    const result = stmt.run(roomId, userId, createdAt);
    return result.changes;
  },

  // Update room activity
  updateRoomActivity: (roomId) => {
    const now = Date.now();
    const stmt = db.prepare(`
      INSERT INTO rooms (room_id, created_at, last_activity)
      VALUES (?, ?, ?)
      ON CONFLICT(room_id) DO UPDATE SET last_activity = ?
    `);
    stmt.run(roomId, now, now, now);
  },

  // Get room info
  getRoomInfo: (roomId) => {
    const stmt = db.prepare('SELECT * FROM rooms WHERE room_id = ?');
    return stmt.get(roomId);
  },

  // Close database connection
  close: () => {
    db.close();
  },
};

module.exports = dbOperations;
