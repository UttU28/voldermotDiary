# Port Usage Analysis Across All Projects

## 📊 Currently Used Ports

| Port | Project | Service | Notes |
|------|---------|---------|-------|
| **3000** | **StockSense** | Frontend | ⚠️ **CONFLICT with voldermotDiary!** |
| **3000** | **voldermotDiary** | Backend | ⚠️ **CONFLICT! Needs to change** |
| 3005 | MemeMaker | Frontend | React/Vite app |
| 3008 | LinkedIn_Reverse_Search | Backend | Node.js/Express |
| 3009 | LinkedIn_Reverse_Search | Frontend | React app |
| 3010 | Saral-Job-Viewer | Frontend | Full-stack React app |
| 3011 | Saral-Job-Viewer | Backend | FastAPI |
| 5000 | Apeksha | Backend | Flask/Gunicorn |
| 7860 | MemeMaker | F5-TTS | Docker container (Gradio) |
| 7880 | livekit-server | Main | LiveKit server |
| 7881 | livekit-server | TCP | LiveKit TCP port |
| 8000 | MemeMaker | Backend | FastAPI |
| 8001 | StockSense | Backend | FastAPI |
| 8002 | resumeForge | Backend | FastAPI |
| 3478 | livekit-server | UDP | STUN/TURN |
| 5349 | livekit-server | TLS | TURN over TLS |
| 50000-50100 | livekit-server | UDP Range | Media ports (UDP) |

## ✅ Available Ports for voldermotDiary Backend

### Recommended Options (Sequential & Clean):
- **3001** ⭐ (Recommended - next available after 3000)
- **3002** ⭐ (Good alternative)
- **3003** ⭐ (Good alternative)
- **3004** ⭐ (Good alternative)
- **3006** (Between MemeMaker frontend and LinkedIn backend)
- **3007** (Between MemeMaker frontend and LinkedIn backend)

### Other Available Ports:
- **3012-4999** (All available)
- **5001-7859** (Available, but close to Apeksha)
- **7861-7879** (Available, but close to F5-TTS)
- **7882-7999** (Available, but close to livekit)
- **8003+** (Available, but higher numbers)

## 🎯 Recommendation

**Use Port 3001** for voldermotDiary backend because:
1. ✅ Sequential and easy to remember
2. ✅ No conflicts with existing services
3. ✅ Close to original port 3000
4. ✅ Follows logical numbering pattern

## 📝 Port Ranges Summary

- **3000-3011**: Mostly used (except 3001-3004, 3006-3007)
- **3012-4999**: ✅ All available
- **5000**: Apeksha
- **5001-7859**: ✅ Available
- **7860**: F5-TTS
- **7861-7879**: ✅ Available
- **7880-7881**: livekit-server
- **7882-7999**: ✅ Available
- **8000-8002**: Used (MemeMaker, StockSense, resumeForge)
- **8003+**: ✅ Available
