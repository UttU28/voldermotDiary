const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const db = require('./database');

const app = express();
const server = http.createServer(app);

// Enable CORS for Flutter app
const io = new Server(server, {
  cors: {
    origin: "*", // Allow all origins for development
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Store connected users and rooms
const rooms = new Map(); // roomId -> Set of socketIds
const users = new Map(); // socketId -> { userId, roomId }

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    connectedUsers: users.size,
    activeRooms: rooms.size
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`✅ Client connected: ${socket.id}`);
  
  // Send connection status to client
  socket.emit('connection-status', { 
    status: 'connected', 
    socketId: socket.id,
    message: 'Successfully connected to server'
  });

  // Handle request for existing strokes
  socket.on('request-strokes', (data) => {
    const { roomId } = data;
    const user = users.get(socket.id);
    const targetRoomId = roomId || (user ? user.roomId : null);
    
    if (targetRoomId) {
      const existingStrokes = db.getStrokesForRoom(targetRoomId);
      console.log(`📦 Requested: Loading ${existingStrokes.length} existing strokes for room: ${targetRoomId}`);
      socket.emit('load-strokes', {
        roomId: targetRoomId,
        strokes: existingStrokes || []
      });
    }
  });

  // Handle client joining a room
  socket.on('join-room', (data) => {
    const { roomId, userId } = data;
    
    if (!roomId) {
      socket.emit('error', { message: 'Room ID is required' });
      return;
    }

    // Leave previous room if any
    if (users.has(socket.id)) {
      const prevRoomId = users.get(socket.id).roomId;
      if (prevRoomId && rooms.has(prevRoomId)) {
        rooms.get(prevRoomId).delete(socket.id);
        if (rooms.get(prevRoomId).size === 0) {
          rooms.delete(prevRoomId);
        }
      }
    }

    // Join new room
    socket.join(roomId);
    
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    rooms.get(roomId).add(socket.id);
    
    users.set(socket.id, { 
      userId: userId || socket.id, 
      roomId: roomId 
    });

    console.log(`📝 User ${socket.id} joined room: ${roomId}`);
    
    // Update room activity
    db.updateRoomActivity(roomId);
    
    // Notify client of successful join
    socket.emit('room-joined', { 
      roomId, 
      userId: userId || socket.id,
      usersInRoom: rooms.get(roomId).size
    });

    // Load existing strokes from database and send to the new user
    // Send after loading page completes (3 seconds) + buffer for DrawingPage initialization
    const existingStrokes = db.getStrokesForRoom(roomId);
    console.log(`📦 Loading ${existingStrokes.length} existing strokes for room: ${roomId}`);
    setTimeout(() => {
      console.log(`📤 Sending load-strokes event with ${existingStrokes.length} strokes`);
      socket.emit('load-strokes', {
        roomId: roomId,
        strokes: existingStrokes || []
      });
    }, 3500); // 3 seconds for loading page + 500ms buffer

    // Notify others in the room
    socket.to(roomId).emit('user-joined', {
      userId: userId || socket.id,
      usersInRoom: rooms.get(roomId).size
    });
  });

  // Handle stroke data
  socket.on('stroke', (data) => {
    const user = users.get(socket.id);
    if (user && user.roomId) {
      // Save stroke to database
      try {
        db.saveStroke({
          roomId: user.roomId,
          userId: data.userId || user.userId,
          socketId: socket.id,
          points: data.points,
          color: data.color,
          width: data.width,
          createdAt: data.createdAt || Date.now(),
        });
        
        // Update room activity
        db.updateRoomActivity(user.roomId);
      } catch (error) {
        console.error('Error saving stroke to database:', error);
      }
      
      // Broadcast stroke to all users in the room except sender
      socket.to(user.roomId).emit('stroke', {
        ...data,
        socketId: socket.id
      });
    }
  });

  // Handle clear canvas request
  socket.on('clear-canvas', (data) => {
    const user = users.get(socket.id);
    if (user && user.roomId) {
      const roomId = data.roomId || user.roomId;
      
      try {
        db.clearRoom(roomId);
      } catch (error) {
        console.error('Error clearing room from database:', error);
      }
      
      io.to(roomId).emit('canvas-cleared', {
        roomId: roomId,
        clearedBy: user.userId || socket.id
      });
    }
  });

  // Handle delete single stroke request
  socket.on('delete-stroke', (data) => {
    const user = users.get(socket.id);
    if (user && user.roomId) {
      const roomId = data.roomId || user.roomId;
      const strokeId = data.strokeId;
      const userId = data.userId;
      const createdAt = data.createdAt;
      
      try {
        // Delete stroke from database
        db.deleteStroke(roomId, userId, createdAt);
        
        // Broadcast delete event to all users in the room
        io.to(roomId).emit('stroke-deleted', {
          roomId: roomId,
          strokeId: strokeId,
          userId: userId,
          createdAt: createdAt,
          deletedBy: user.userId || socket.id
        });
      } catch (error) {
        console.error('Error deleting stroke from database:', error);
      }
    }
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    console.log(`❌ Client disconnected: ${socket.id}`);
    
    const user = users.get(socket.id);
    if (user && user.roomId) {
      const roomId = user.roomId;
      
      if (rooms.has(roomId)) {
        rooms.get(roomId).delete(socket.id);
        
        // Notify others in the room
        socket.to(roomId).emit('user-left', {
          userId: user.userId,
          usersInRoom: rooms.get(roomId).size
        });

        // Clean up empty rooms
        if (rooms.get(roomId).size === 0) {
          rooms.delete(roomId);
        }
      }
    }
    
    users.delete(socket.id);
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`🪄 Voldermot Diary Backend Server running on port ${PORT}`);
  console.log(`📡 WebSocket server ready for connections`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});
