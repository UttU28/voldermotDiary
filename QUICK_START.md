# 🚀 Quick Start Guide

## Backend Setup

1. **Navigate to backend folder:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start the server:**
   ```bash
   npm start
   ```
   
   Server runs on `http://localhost:3000`

## Flutter App Setup

1. **Navigate to Flutter project:**
   ```bash
   cd voldermot_diary
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Update server URL in `lib/main.dart`:**
   - For **Windows/Web**: `http://localhost:3000` ✅ (already set)
   - For **Android Emulator**: `http://10.0.2.2:3000`
   - For **Physical Android Device**: `http://YOUR_COMPUTER_IP:3000` (e.g., `http://192.168.1.100:3000`)

4. **Run the app:**
   ```bash
   flutter run
   ```

## Testing Connection

1. Start the backend server first
2. Run the Flutter app
3. Tap **"Connect to Server"** button
4. You should see:
   - ✅ Green status indicator
   - "Connected" status
   - Socket ID displayed
5. Tap **"Join Room"** to join the default room
6. Status will show number of users in room

## Health Check

Visit `http://localhost:3000/health` in browser to check server status.
