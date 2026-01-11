# SQLite Database Setup

## Installation

After adding SQLite support, run:

```bash
cd backend
npm install
```

This will install `better-sqlite3` package.

## Database Location

The SQLite database is stored locally in:
```
backend/data/voldermot_diary.db
```

## Features

1. **Persistent Storage**: All strokes are saved to the database
2. **Session Persistence**: When users rejoin a room, they see all previous drawings
3. **Synchronized Clearing**: When one device clears the canvas, it clears on all devices and in the database
4. **Room Management**: Tracks room activity and creation times

## Database Schema

### strokes table
- `id`: Primary key
- `room_id`: Room identifier
- `user_id`: User who created the stroke
- `socket_id`: Socket connection ID
- `points`: JSON array of stroke points (normalized coordinates)
- `color`: Stroke color (hex)
- `width`: Stroke width
- `created_at`: Timestamp when stroke was created

### rooms table
- `room_id`: Primary key
- `created_at`: When room was first created
- `last_activity`: Last activity timestamp

## How It Works

1. **On Join**: When a user joins a room, all existing strokes are loaded from the database
2. **On Draw**: When a stroke is received, it's saved to the database and broadcast to other users
3. **On Clear**: When canvas is cleared, database is cleared and all clients are notified

## Data Directory

The `data/` directory is automatically created and is gitignored to keep the database local.
