# Voldermot Diary Backend

Real-time WebSocket server for the collaborative handwriting app.

## Setup

```bash
npm install
```

## Run

```bash
# Development (with auto-reload)
npm run dev

# Production
npm start
```

Server runs on `http://localhost:3000`

## Endpoints

- `GET /health` - Health check and server status

## WebSocket Events

### Client → Server
- `join-room` - Join a room with `{ roomId, userId }`
- `stroke` - Send stroke data (future use)

### Server → Client
- `connection-status` - Connection established
- `room-joined` - Successfully joined a room
- `user-joined` - Another user joined the room
- `user-left` - A user left the room
- `stroke` - Receive stroke data from other users
